import os
import requests
import yt_dlp
import logging
from telegram import InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Resolve potential shortened URLs
def resolve_url(url):
    try:
        response = requests.get(url)
        return response.url
    except Exception as e:
        logger.error(f"Failed to resolve URL: {e}")
        return url

# Function to download the video using yt-dlp with cookies support
def download_video(url, extract_audio=False):
    resolved_url = resolve_url(url)
    ydl_opts = {
        'format': 'bestvideo+bestaudio/best' if not extract_audio else 'bestaudio/best',
        'outtmpl': 'downloads/%(title)s.%(ext)s',  # Adjust the output directory as needed
        'noplaylist': True,
        'cookiefile': 'cookies.txt',  # Use your saved cookies from the browser
        'http_headers': {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:94.0) Gecko/20100101 Firefox/94.0',
            'Referer': resolved_url,
        },
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': '192',
        }] if extract_audio else []
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info_dict = ydl.extract_info(resolved_url, download=True)
            file_path = ydl.prepare_filename(info_dict)
            if extract_audio:
                file_path = file_path.rsplit('.', 1)[0] + '.mp3'
            return file_path, info_dict
    except Exception as e:
        logger.error(f"Error downloading video from {resolved_url}: {e}")
        return None, None

# Function to download images
def download_image(url):
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
    welcome_message = f"Welcome, {user_first_name}! 😊\nI'm Ronin Downloader bot. Send me a video link from Instagram, Facebook, or TikTok, and I'll download it for you in HD!"
    await update.message.reply_text(welcome_message)

# Handle URLs and download video or image
async def handle_url(update, context):
    url = update.message.text.strip()
    await update.message.reply_text(f'Downloading from {url}...')
    
    try:
        if 'douyin' in url or 'tiktok' in url:
            video_file, info_dict = download_video(url)
            if video_file:
                buttons = [
                    [InlineKeyboardButton("URL", url=url)],
                    [InlineKeyboardButton("MP3", callback_data=f"mp3|{url}")]
                ]
                reply_markup = InlineKeyboardMarkup(buttons)
                with open(video_file, 'rb') as video:
                    await context.bot.send_video(chat_id=update.effective_chat.id, video=video, reply_markup=reply_markup)
            else:
                await update.message.reply_text('Failed to download the video. Make sure the link is correct or that the video is not private/restricted.')
        else:
            image_file = download_image(url)
            if image_file:
                buttons = [
                    [InlineKeyboardButton("URL", url=url)]
                ]
                reply_markup = InlineKeyboardMarkup(buttons)
                with open(image_file, 'rb') as image:
                    await context.bot.send_photo(chat_id=update.effective_chat.id, photo=image, reply_markup=reply_markup)
            else:
                await update.message.reply_text('Failed to download the image. Make sure the link is correct or that the image is not private/restricted.')
    except Exception as e:
        logger.error(f"Error handling URL: {e}")
        await update.message.reply_text(f'Error: {str(e)}')

# Handle callback queries for MP3 download
async def handle_callback_query(update, context):
    query = update.callback_query
    await query.answer()
    data = query.data.split('|')
    if data[0] == 'mp3':
        url = data[1]
        await query.edit_message_text(text=f'Downloading MP3 from {url}...')
        try:
            mp3_file, _ = download_video(url, extract_audio=True)
            if mp3_file:
                with open(mp3_file, 'rb') as audio:
                    await context.bot.send_audio(chat_id=update.effective_chat.id, audio=audio)
            else:
                await query.edit_message_text(text='Failed to download the MP3. Make sure the link is correct or that the video is not private/restricted.')
        except Exception as e:
            logger.error(f"Error handling MP3 download: {e}")
            await query.edit_message_text(text=f'Error: {str(e)}')

# Set up the bot
def main():
    application = Application.builder().token(os.getenv('TELEGRAM_TOKEN')).build()

    application.add_handler(CommandHandler('start', start))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_url))
    application.add_handler(CallbackQueryHandler(handle_callback_query))

    application.run_polling()

if __name__ == '__main__':
    main()
