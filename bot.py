import os
from telegram.ext import Application, CommandHandler, MessageHandler
from telegram.ext import filters
import yt_dlp

# Function to download the video using yt-dlp
def download_video(url):
    ydl_opts = {
        'format': 'best',
        'outtmpl': 'downloads/%(title)s.%(ext)s',
        'noplaylist': True,
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info_dict = ydl.extract_info(url, download=True)
        video_title = ydl.prepare_filename(info_dict)
        return video_title

# Command to start the bot
async def start(update, context):
    await update.message.reply_text('Send me a video link, and I\'ll download it for you in HD!')

# Handle URLs and download video
async def handle_url(update, context):
    url = update.message.text
    await update.message.reply_text(f'Downloading video from {url}...')
    try:
        video_file = download_video(url)
        await context.bot.send_video(chat_id=update.effective_chat.id, video=open(video_file, 'rb'))
    except Exception as e:
        await update.message.reply_text('Failed to download video. Make sure the link is correct.')

# Set up the bot
def main():
    application = Application.builder().token(os.getenv('TELEGRAM_TOKEN')).build()

    application.add_handler(CommandHandler('start', start))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_url))

    application.run_polling()

if __name__ == '__main__':
    main()
