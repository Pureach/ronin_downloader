import os
import logging
from telegram import Update
from telegram.ext import Updater, CommandHandler, MessageHandler, Filters, CallbackContext
import yt_dlp

# Enable logging
logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)
logger = logging.getLogger(__name__)

# Start command handler
def start(update: Update, context: CallbackContext) -> None:
    update.message.reply_text('Send me a TikTok/Douyin video link, and I will download it for you in HD!')

# Download video
def download_video(update: Update, context: CallbackContext) -> None:
    url = update.message.text
    chat_id = update.message.chat_id

    ydl_opts = {
        'format': 'best',
        'outtmpl': 'downloads/%(title)s.%(ext)s'
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            info_dict = ydl.extract_info(url, download=True)
            video_file = ydl.prepare_filename(info_dict)
            context.bot.send_video(chat_id=chat_id, video=open(video_file, 'rb'))
            os.remove(video_file)  # Remove file after sending it
        except Exception as e:
            update.message.reply_text('Failed to download the video. Make sure the link is correct.')

# Error handler
def error(update: Update, context: CallbackContext) -> None:
    logger.warning(f'Update {update} caused error {context.error}')

def main() -> None:
    TOKEN = os.getenv('TELEGRAM_TOKEN')

    # Create the Updater and pass it your bot's token.
    updater = Updater(TOKEN)

    # Get the dispatcher to register handlers
    dispatcher = updater.dispatcher

    # Register the command handlers
    dispatcher.add_handler(CommandHandler("start", start))

    # Register the message handler for URLs
    dispatcher.add_handler(MessageHandler(Filters.text & ~Filters.command, download_video))

    # Log all errors
    dispatcher.add_error_handler(error)

    # Start the Bot
    updater.start_polling()
    updater.idle()

if __name__ == '__main__':
    main()
