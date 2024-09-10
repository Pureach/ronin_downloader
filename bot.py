import os
import requests
import yt_dlp
import logging
import shutil
from telegram import InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters
import asyncio

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Ensure the downloads directory exists
if not os.path.exists('downloads'):
    os.makedirs('downloads')

# List to keep track of downloaded URLs
downloaded_urls = []

# Resolve potential shortened URLs
def resolve_url(url):
    try:
        response = requests.get(url)
        return response.url
    except Exception as e:
        logger.error(f"Failed to resolve URL: {e}")
        return url

# Function to download media using yt-dlp
async def download_media(url, progress_callback=None):
    resolved_url = resolve_url(url)
    ydl_opts = {
        'format': 'bestvideo[height<=1080]+bestaudio/best',
        'outtmpl': 'downloads/%(title)s.%(ext)s',
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
    except Exception as e:
        logger.error(f"Error downloading media from {resolved_url}: {e}")
        return None, None

# Function to download images
async def download_image(url):
    resolved_url = resolve_url(url)
    try:
        response = requests.get(resolved_url, stream=True)
        if response.status_code == 200:
            file_path = os.path.join('downloads', os.path.basename(resolved_url))
            with open(file_path, 'wb') as file:
                for chunk in response.iter_content(1024):
                    file.write(chunk)
            return file_path
        else:
            logger.error(f"Failed to download image: {response.status_code}")
            return None
    except Exception as e:
        logger.error(f"Error downloading image from {resolved_url}: {e}")
        return None

# Command to start the bot and welcome new users
async def start(update, context):
    user_first_name = update.effective_user.first_name
    welcome_message = (
        f"Welcome, {user_first_name}! 😊\n"
        "I'm Ronin Downloader bot. Send me a video or image link from various media platforms, "
        "and I'll download it for you in HD!"
    )
    await update.message.reply_text(welcome_message)

# Command to provide help to users
async def help_command(update, context):
    help_text = (
        "Here's how to use the bot:\n"
        "/start - Welcome message\n"
        "/help - Show this help message\n"
        "Send a media link from platforms like Instagram, Facebook, TikTok, YouTube, or Twitter to download it."
    )
    await update.message.reply_text(help_text)

# Handle URLs and download video or image
async def handle_url(update, context):
    url = update.message.text.strip()

    # Send initial message and store it in a variable
    message = await update.message.reply_text('Starting download...')

    async def progress_hook(d):
        if d['status'] == 'downloading':
            percent = d.get('_percent_str', '0.0%')
            speed = d.get('_speed_str', '0 KB/s')
            eta = d.get('_eta_str', 'unknown')
            # Update the message every 10 seconds to avoid flooding
            if d.get('elapsed', 0) % 10 == 0:
                await message.edit_text(f"Downloading: {percent} at {speed} ETA: {eta}")
        elif d['status'] == 'finished':
            await message.edit_text('Download complete')
            await update.message.reply_text('Download complete!')

    try:
        if 'youtube.com' in url:
            # Handle YouTube videos
            video_file, info_dict = await download_media(url, progress_callback=progress_hook)
            if video_file:
                buttons = [[InlineKeyboardButton("URL", url=url)]]
                reply_markup = InlineKeyboardMarkup(buttons)
                with open(video_file, 'rb') as video:
                    await context.bot.send_video(chat_id=update.effective_chat.id, video=video, reply_markup=reply_markup)
                downloaded_urls.append(url)
            else:
                await message.edit_text('Failed to download the video. The link might be incorrect or the video might be private/restricted.')

        elif 'douyin' in url or 'tiktok' in url:
            # Handle TikTok videos
            video_file, info_dict = await download_media(url, progress_callback=progress_hook)
            if video_file:
                buttons = [[InlineKeyboardButton("URL", url=url)]]
                reply_markup = InlineKeyboardMarkup(buttons)
                with open(video_file, 'rb') as video:
                    await context.bot.send_video(chat_id=update.effective_chat.id, video=video, reply_markup=reply_markup)
                downloaded_urls.append(url)
            else:
                await message.edit_text('Failed to download the video. The link might be incorrect or the video might be private/restricted.')

        elif 'instagram.com' in url:
            # Handle Instagram media (e.g., videos and images)
            media_file = await download_media(url, progress_callback=progress_hook)
            if media_file:
                buttons = [[InlineKeyboardButton("URL", url=url)]]
                reply_markup = InlineKeyboardMarkup(buttons)
                with open(media_file, 'rb') as media:
                    await context.bot.send_document(chat_id=update.effective_chat.id, document=media, reply_markup=reply_markup)
                downloaded_urls.append(url)
            else:
                await message.edit_text('Failed to download the media. The link might be incorrect or the media might be private/restricted.')

        elif 'facebook.com' in url:
            # Handle Facebook videos
            media_file = await download_media(url, progress_callback=progress_hook)
            if media_file:
                buttons = [[InlineKeyboardButton("URL", url=url)]]
                reply_markup = InlineKeyboardMarkup(buttons)
                with open(media_file, 'rb') as media:
                    await context.bot.send_video(chat_id=update.effective_chat.id, video=media, reply_markup=reply_markup)
                downloaded_urls.append(url)
            else:
                await message.edit_text('Failed to download the video. The link might be incorrect or the video might be private/restricted.')

        elif 'twitter.com' in url:
            # Handle Twitter media
            media_file = await download_media(url, progress_callback=progress_hook)
            if media_file:
                buttons = [[InlineKeyboardButton("URL", url=url)]]
                reply_markup = InlineKeyboardMarkup(buttons)
                with open(media_file, 'rb') as media:
                    await context.bot.send_document(chat_id=update.effective_chat.id, document=media, reply_markup=reply_markup)
                downloaded_urls.append(url)
            else:
                await message.edit_text('Failed to download the media. The link might be incorrect or the media might be private/restricted.')

        else:
            image_file = await download_image(url)
            if image_file:
                buttons = [[InlineKeyboardButton("URL", url=url)]]
                reply_markup = InlineKeyboardMarkup(buttons)
                with open(image_file, 'rb') as image:
                    await context.bot.send_photo(chat_id=update.effective_chat.id, photo=image, reply_markup=reply_markup)
                downloaded_urls.append(url)
            else:
                await message.edit_text('Failed to download the image. The link might be incorrect or the image might be private/restricted.')

    except Exception as e:
        logger.error(f"Error handling URL: {e}")
        await message.edit_text(f'Error: {str(e)}')

# Cleanup old files
def cleanup_downloads():
    try:
        shutil.rmtree('downloads')
        os.makedirs('downloads')
        logger.info('Downloads directory cleaned up')
    except Exception as e:
        logger.error(f"Error cleaning up downloads directory: {e}")

# Set up the bot
def main():
    application = Application.builder().token(os.getenv('TELEGRAM_TOKEN')).build()

    application.add_handler(CommandHandler('start', start))
    application.add_handler(CommandHandler('help', help_command))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_url))

    application.run_polling()

if __name__ == '__main__':
    main()
