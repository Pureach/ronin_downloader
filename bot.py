import os
import requests
import yt_dlp
from telegram.ext import Application, CommandHandler, MessageHandler, filters

# Ensure download directory exists
if not os.path.exists('downloads'):
    os.makedirs('downloads')

# Resolve potential shortened URLs
def resolve_url(url):
    try:
        response = requests.get(url)
        return response.url
    except Exception as e:
        print(f"Failed to resolve URL: {e}")
        return url

# Function to download video or image
def download_content(url):
    resolved_url = resolve_url(url)
    
    # Determine if the URL is an image or video
    if any(resolved_url.endswith(ext) for ext in ['.jpg', '.jpeg', '.png', '.gif']):
        return download_image(resolved_url)
    else:
        return download_video(resolved_url)

# Function to download images
def download_image(url):
    try:
        response = requests.get(url, stream=True)
        if response.status_code == 200:
            image_path = os.path.join('downloads', 'image' + os.path.splitext(url)[-1])
            with open(image_path, 'wb') as f:
                for chunk in response.iter_content(1024):
                    f.write(chunk)
            return image_path
        else:
            print(f"Failed to download image: {response.status_code}")
            return None
    except Exception as e:
        print(f"Error downloading image: {e}")
        return None

# Function to download videos using yt-dlp with cookies support
def download_video(url):
    ydl_opts = {
        'format': 'best',
        'outtmpl': 'downloads/%(title)s.%(ext)s',
        'noplaylist': True,
        'cookiefile': 'cookies.txt',
        'http_headers': {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:94.0) Gecko/20100101 Firefox/94.0',
            'Referer': url,
        },
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info_dict = ydl.extract_info(url, download=True)
            video_title = ydl.prepare_filename(info_dict)
            return video_title
    except Exception as e:
        print(f"Error downloading video from {url}: {e}")
        return None

# Command to start the bot and welcome new users
async def start(update, context):
    user_first_name = update.effective_user.first_name
    welcome_message = f"Welcome, {user_first_name}! 😊\nI'm Ronin Downloader bot. Send me a video or image link from Instagram, Facebook, TikTok, or Douyin, and I'll download it for you in HD!"
    await update.message.reply_text(welcome_message)

# Handle URLs and download content
async def handle_url(update, context):
    url = update.message.text.strip()
    await update.message.reply_text(f'Downloading content from {url}...')
    
    try:
        file_path = download_content(url)
        if file_path:
            if file_path.endswith(('.jpg', '.jpeg', '.png', '.gif')):
                with open(file_path, 'rb') as image:
                    await context.bot.send_photo(chat_id=update.effective_chat.id, photo=image)
            else:
                with open(file_path, 'rb') as video:
                    await context.bot.send_video(chat_id=update.effective_chat.id, video=video)
        else:
            await update.message.reply_text('Failed to download the content. Make sure the link is correct or that the content is not private/restricted.')
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
