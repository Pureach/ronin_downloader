import os
import requests
from telegram.ext import Application, CommandHandler, MessageHandler
from telegram.ext import filters
import yt_dlp
import logging

# Setup logging for debugging purposes
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Resolve potential shortened URLs
def resolve_url(url):
    try:
        response = requests.get(url)
        logger.info(f"Resolved URL: {response.url}")
        return response.url
    except Exception as e:
        logger.error(f"Failed to resolve URL: {e}")
        return url

# Function to download the video using yt-dlp with cookies support
def download_video(url):
    resolved_url = resolve_url(url)
    ydl_opts = {
        'format': 'best',
        'outtmpl': 'downloads/%(title)s.%(ext)s',
        'noplaylist': True,
        'cookiefile': 'cookies.txt',  # Use your saved cookies from browser
        'http_headers': {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:94.0) Gecko/20100101 Firefox/94.0',
            'Referer': resolved_url,
        },
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info_dict = ydl.extract_info(resolved_url, download=True)
            video_title = ydl.prepare_filename(info_dict)
            logger.info(f"Successfully downloaded video: {video_title}")
            return video_title
    except yt_dlp.utils.DownloadError as e:
        logger.error(f"Download error: {e}")
    except Exception as e:
        logger.error(f"Unexpected error during download: {e}")
    return None

# Command to start the bot and welcome new users
async def start(update, context):
    user_first_name = update.effective_user.first_name
    welcome_message = f"Welcome, {user_first_name}! 😊\nI'm Ronin Downloader bot. Send me a video link from Instagram, Facebook, or TikTok, and I'll download it for you in HD!"
    await update.message.reply_text(welcome_message)

# Handle URLs and download video
async def handle_url(update, context):
    url = update.message.text.strip()
    await update.message.reply_text(f'Downloading video from {url}...')
    
    try:
        video_file = download_video(url)
        if video_file:
            await context.bot.send_video(chat_id=update.effective_chat.id, video=open(video_file, 'rb'))
        else:
            await update.message.reply_text('Failed to download video. Make sure the link is correct or that the video is not private/restricted.')
    except Exception as e:
        logger.error(f"Error processing video download: {e}")
        await update.message.reply_text(f'Error: {str(e)}')

# Set up the bot
def main():
    application = Application.builder().token(os.getenv('TELEGRAM_TOKEN')).build()

    application.add_handler(CommandHandler('start', start))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_url))

    application.run_polling()

if __name__ == '__main__':
    main()
