import os
import json
import requests
import yt_dlp
import logging
import shutil
import time
from datetime import datetime, timedelta
from telegram import InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters, CallbackContext

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Ensure the downloads directory exists
DOWNLOADS_DIR = 'downloads'
if not os.path.exists(DOWNLOADS_DIR):
    os.makedirs(DOWNLOADS_DIR)

# File to store downloaded URL metadata
METADATA_FILE = 'metadata.json'

# Default settings
DEFAULT_SETTINGS = {
    'video_quality': 'bestvideo[height<=1080]+bestaudio/best',
    'image_format': 'jpeg'
}

user_settings = {}  # To store user-specific settings

# Default cleanup settings
CLEANUP_DAYS = 7  # Default to 7 days
CLEANUP_INTERVAL = 86400  # 24 hours in seconds

# Load or initialize metadata
def load_metadata():
    if os.path.exists(METADATA_FILE):
        with open(METADATA_FILE, 'r') as file:
            return json.load(file)
    return {}

def save_metadata(metadata):
    with open(METADATA_FILE, 'w') as file:
        json.dump(metadata, file)

metadata = load_metadata()

# Resolve potential shortened URLs
def resolve_url(url):
    try:
        response = requests.get(url)
        response.raise_for_status()
        return response.url
    except requests.RequestException as e:
        logger.error(f"Failed to resolve URL: {e}")
        return url

# Function to download the video using yt-dlp with cookies support
def download_video(url, quality, progress_callback=None):
    resolved_url = resolve_url(url)
    ydl_opts = {
        'format': quality,
        'outtmpl': f'{DOWNLOADS_DIR}/%(title)s.%(ext)s',
        'noplaylist': True,
        'cookiefile': 'cookies.txt',
        'http_headers': {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:94.0) Gecko/20100101 Firefox/94.0',
            'Referer': resolved_url,
        },
        'progress_hooks': [progress_callback] if progress_callback else [],
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info_dict = ydl.extract_info(resolved_url, download=True)
            file_path = ydl.prepare_filename(info_dict)
            return file_path, info_dict
    except yt_dlp.utils.DownloadError as e:
        logger.error(f"Error downloading video from {resolved_url}: {e}")
        return None, None

# Function to download images
def download_image(url, format):
    resolved_url = resolve_url(url)
    try:
        response = requests.get(resolved_url, stream=True)
        response.raise_for_status()
        file_path = os.path.join(DOWNLOADS_DIR, f"{os.path.basename(resolved_url).split('.')[0]}.{format}")
        with open(file_path, 'wb') as file:
            for chunk in response.iter_content(1024):
                file.write(chunk)
        return file_path
    except requests.RequestException as e:
        logger.error(f"Error downloading image from {resolved_url}: {e}")
        return None

# Command to start the bot and welcome new users
async def start(update, context):
    user_first_name = update.effective_user.first_name
    welcome_message = (f"Welcome, {user_first_name}! 😊\n"
                       "I'm Ronin Downloader bot. Send me a video or image link from popular media platforms, "
                       "and I'll download it for you in HD!")
    await update.message.reply_text(welcome_message)

# Handle URLs and download video or image
async def handle_url(update, context):
    url = update.message.text.strip()
    user_id = update.effective_user.id
    settings = user_settings.get(user_id, DEFAULT_SETTINGS)

    # Send initial message
    message = await update.message.reply_text('Processing your request...')

    async def progress_hook(d):
        if d['status'] == 'downloading':
            percent = d['_percent_str']
            speed = d['_speed_str']
            eta = d['_eta_str']
            # Update message with download progress
            await message.edit_text(f"Downloading: {percent} at {speed} ETA: {eta}")
        elif d['status'] == 'finished':
            # Notify user when download is complete
            await message.edit_text('Download complete')

    try:
        # Define platform-specific patterns
        platforms = {
            'tiktok': 'tiktok',
            'douyin': 'douyin',
            'instagram': 'instagram',
            'facebook': 'facebook',
            'youtube': 'youtube',
            'twitter': 'twitter',
            'vimeo': 'vimeo'
        }

        # Detect platform and download accordingly
        platform_detected = None
        for platform, keyword in platforms.items():
            if keyword in url:
                platform_detected = platform
                break

        if platform_detected:
            if platform_detected in ['tiktok', 'douyin', 'instagram', 'facebook', 'youtube']:
                video_file, info_dict = download_video(url, settings['video_quality'], progress_callback=progress_hook)
                if video_file:
                    buttons = [
                        [InlineKeyboardButton("URL", url=url)]
                    ]
                    reply_markup = InlineKeyboardMarkup(buttons)
                    with open(video_file, 'rb') as video:
                        await context.bot.send_video(chat_id=update.effective_chat.id, video=video, reply_markup=reply_markup)
                    # Update metadata
                    metadata[url] = {'type': 'video', 'timestamp': datetime.now().isoformat()}
                    save_metadata(metadata)
                else:
                    await message.edit_text('Failed to download the video. The link might be incorrect or the video might be private/restricted.')
            elif platform_detected in ['twitter', 'vimeo']:
                image_file = download_image(url, settings['image_format'])
                if image_file:
                    buttons = [
                        [InlineKeyboardButton("URL", url=url)]
                    ]
                    reply_markup = InlineKeyboardMarkup(buttons)
                    with open(image_file, 'rb') as image:
                        await context.bot.send_photo(chat_id=update.effective_chat.id, photo=image, reply_markup=reply_markup)
                    # Update metadata
                    metadata[url] = {'type': 'image', 'timestamp': datetime.now().isoformat()}
                    save_metadata(metadata)
                else:
                    await message.edit_text('Failed to download the image. The link might be incorrect or the image might be private/restricted.')
            else:
                await message.edit_text('Unsupported media platform.')
        else:
            await message.edit_text('Unsupported media platform or failed to identify the content.')

    except Exception as e:
        logger.error(f"Error handling URL: {e}")
        await message.edit_text(f'Error: {str(e)}')

# Cleanup old files and links automatically
def auto_cleanup():
    cutoff_date = datetime.now() - timedelta(days=CLEANUP_DAYS)
    deleted_files = []
    deleted_links = []

    # Remove old files
    for file_name in os.listdir(DOWNLOADS_DIR):
        file_path = os.path.join(DOWNLOADS_DIR, file_name)
        if os.path.isfile(file_path):
            file_mod_time = datetime.fromtimestamp(os.path.getmtime(file_path))
            if file_mod_time < cutoff_date:
                os.remove(file_path)
                deleted_files.append(file_name)

    # Remove old links from metadata
    to_remove = [url for url, data in metadata.items() if datetime.fromisoformat(data['timestamp']) < cutoff_date]
    for url in to_remove:
        del metadata[url]
        deleted_links.append(url)

    save_metadata(metadata)

    if deleted_files or deleted_links:
        log_msg = "Automatic cleanup complete.\n"
        if deleted_files:
            log_msg += f"Deleted files:\n" + '\n'.join(deleted_files) + '\n'
        if deleted_links:
            log_msg += f"Deleted links:\n" + '\n'.join(deleted_links)
        logger.info(log_msg)
    else:
        logger.info("No files or links were old enough to delete during automatic cleanup.")

# Set up the bot
def main():
    application = Application.builder().token(os.getenv('TELEGRAM_TOKEN')).build()

    application.add_handler(CommandHandler('start', start))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_url))

    # Schedule periodic cleanup (e.g., every 24 hours)
    application.job_queue.run_repeating(auto_cleanup, interval=CLEANUP_INTERVAL, first=0)

    application.run_polling()

if __name__ == '__main__':
    main()
