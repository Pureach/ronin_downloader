import os
from telegram.ext import Updater, CommandHandler, MessageHandler, Filters
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
def start(update, context):
    update.message.reply_text('Send me a video link, and I\'ll download it for you in HD!')

# Handle URLs and download video
def handle_url(update, context):
    url = update.message.text
    update.message.reply_text(f'Downloading video from {url}...')
    try:
        video_file = download_video(url)
        context.bot.send_video(chat_id=update.effective_chat.id, video=open(video_file, 'rb'))
    except Exception as e:
        update.message.reply_text('Failed to download video. Make sure the link is correct.')

# Set up the bot
def main():
    updater = Updater(token=os.getenv('TELEGRAM_TOKEN'), use_context=True)
    dp = updater.dispatcher

    dp.add_handler(CommandHandler('start', start))
    dp.add_handler(MessageHandler(Filters.text & ~Filters.command, handle_url))

    updater.start_polling()
    updater.idle()

if __name__ == '__main__':
    main()
