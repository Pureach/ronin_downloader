import os
import requests
import yt_dlp
from telegram.ext import Application, CommandHandler, MessageHandler, filters
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Ensure downloads directory exists
if not os.path.exists('downloads'):
    os.makedirs('downloads')

# Resolve potential shortened URLs
def resolve_url(url):
    try:
        response = requests.get(url, timeout=10)
        return response.url
    except Exception as e:
        print(f"Failed to resolve URL: {e}")
        return url

# Function to download the video using yt-dlp with cookies support
def download_video(url):
    resolved_url = resolve_url(url)
    ydl_opts = {
        'format': 'best',
        'outtmpl': 'downloads/%(title)s.%(ext)s',
        'noplaylist': True,
        'cookiefile': 'cookies.txt',  # Ensure the cookies.txt file exists
        'http_headers': {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:94.0) Gecko/20100101 Firefox/94.0',
            'Referer': resolved_url,
        },
        'retries': 3,  # Retry downloading the video up to 3 times
        'timeout': 60,  # Set a timeout of 60 seconds
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info_dict = ydl.extract_info(resolved_url, download=True)
            video_title = ydl.prepare_filename(info_dict)
            return video_title
    except Exception as e:
        print(f"Error downloading video from {resolved_url}: {e}")
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
            await update.message.reply_text('Failed to download the video. Make sure the link is correct or that the video is not private/restricted.')
    except Exception as e:
        await update.message.reply_text(f'Error: {str(e)}')

# Set up the bot
def main():
    application = Application.builder().token(os.getenv('TELEGRAM_TOKEN')).build()

    application.add_handler(CommandHandler('start', start))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_url))

    application.run_polling()

if __name__ == '__main__':
    main()
