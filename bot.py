import os
import requests
import yt_dlp
import logging
import shutil
import time
from pathlib import Path
from telegram import InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters, CallbackContext, Update

# Configure logging
def configure_logging():
    logging.basicConfig(level=logging.INFO)
    return logging.getLogger(__name__)

logger = configure_logging()

# Ensure the downloads directory exists
def ensure_downloads_directory():
    downloads_dir = Path('downloads')
    downloads_dir.mkdir(exist_ok=True)
    return downloads_dir

downloads_dir = ensure_downloads_directory()

# Automatic cleanup of old files
def auto_cleanup(downloads_dir, age_limit_days=7):
    now = time.time()
    age_limit_seconds = age_limit_days * 86400  # Convert days to seconds
    for file in downloads_dir.iterdir():
        if now - file.stat().st_mtime > age_limit_seconds:
            try:
                file.unlink()
                logger.info(f"Deleted old file: {file}")
            except Exception as e:
                logger.error(f"Error deleting file {file}: {e}")

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
def download_video(url, progress_callback=None):
    resolved_url = resolve_url(url)
    ydl_opts = {
        'format': 'bestvideo[height<=1080]+bestaudio/best',
        'outtmpl': f'{downloads_dir}/%(title)s.%(ext)s',
        'noplaylist': True,
        'cookiefile': 'cookies.txt',
        'http_headers': {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:94.0) Gecko/20100101 Firefox/94.0',
            'Referer': resolved_url,
        },
        'progress_hooks': [progress_callback] if progress_callback else []
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info_dict = ydl.extract_info(resolved_url, download=True)
            file_path = ydl.prepare_filename(info_dict)
            return file_path, info_dict
    except yt_dlp.DownloadError as e:
        logger.error(f"Error downloading video from {resolved_url}: {e}")
        return None, None
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return None, None

# Function to download images
def download_image(url):
    resolved_url = resolve_url(url)
    try:
        response = requests.get(resolved_url, stream=True)
        response.raise_for_status()
        file_path = downloads_dir / os.path.basename(resolved_url)
        with open(file_path, 'wb') as file:
            for chunk in response.iter_content(1024):
                file.write(chunk)
        return file_path
    except requests.RequestException as e:
        logger.error(f"Error downloading image from {resolved_url}: {e}")
        return None

# Handle URLs and download video or image
async def handle_url(update: Update, context: CallbackContext):
    url = update.message.text.strip()

    async def progress_hook(d):
        if d['status'] == 'downloading':
            percent = d['_percent_str']
            await update.message.edit_text(f"Downloading: {percent} at {d['_speed_str']} ETA: {d['_eta_str']}")
        elif d['status'] == 'finished':
            await update.message.edit_text('Download complete')

    try:
        if 'douyin' in url or 'tiktok' in url:
            video_file, info_dict = download_video(url, progress_callback=progress_hook)
            if video_file:
                buttons = [[InlineKeyboardButton("URL", url=url)]]
                reply_markup = InlineKeyboardMarkup(buttons)
                with open(video_file, 'rb') as video:
                    await context.bot.send_video(chat_id=update.effective_chat.id, video=video, reply_markup=reply_markup)
                downloaded_urls.append(url)
            else:
                await update.message.reply_text('Failed to download the video. The link might be incorrect or the video might be private/restricted.')
        else:
            image_file = download_image(url)
            if image_file:
                buttons = [[InlineKeyboardButton("URL", url=url)]]
                reply_markup = InlineKeyboardMarkup(buttons)
                with open(image_file, 'rb') as image:
                    await context.bot.send_photo(chat_id=update.effective_chat.id, photo=image, reply_markup=reply_markup)
                downloaded_urls.append(url)
            else:
                await update.message.reply_text('Failed to download the image. The link might be incorrect or the image might be private/restricted.')
    except Exception as e:
        logger.error(f"Error handling URL: {e}")
        await update.message.reply_text(f'Error: {str(e)}')

# Set up the bot
def main():
    application = Application.builder().token(os.getenv('TELEGRAM_TOKEN')).build()

    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_url))

    # Schedule automatic cleanup
    auto_cleanup(downloads_dir)

    # Run the bot
    application.run_polling()

if __name__ == '__main__':
    while True:
        try:
            main()
        except Exception as e:
            logger.error(f"Bot crashed with error: {e}")
            time.sleep(60)  # Wait before restarting
