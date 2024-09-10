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
    update.message.reply_text('Send me a video link from TikTok, Douyin, or any supported platform, and I will download it for you in HD!')

# Download video function
def download_video(update: Update, context: CallbackContext) -> None:
    url = update.message.text
    chat_id = update.message.chat_id

    ydl_opts = {
        'format': 'bestvideo+bestaudio/best',  # Download the best video and best audio available
        'outtmpl': 'downloads/%(title)s.%(ext)s',  # Save video in the downloads folder with the title of the video
        'merge_output_format': 'mp4',  # Ensure audio and video are merged in an MP4 container if separate
        'noplaylist': True  # Ensure we download only one video, not an entire playlist
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            # Extract video information and download it
            info_dict = ydl.extract_info(url, download=True)
            video_file = ydl.prepare_filename(info_dict)
            
            # Send the downloaded video file to the user
            context.bot.send_video(chat_id=chat_id, video=open(video_file, 'rb'))
            
            # Remove the video file after it has been sent
            os.remove(video_file)
        except Exception as e:
            logger.error(f"Error downloading video: {e}")
            update.message.reply_text('Failed to download the video. Ensure the link is correct and from a supported platform.')

# Error handler
def error(update: Update, context: CallbackContext) -> None:
    logger.warning(f'Update {update} caused error {context.error}')

def main() -> None:
    TOKEN = os.getenv('TELEGRAM_TOKEN')

    # Create the Updater and pass it your bot's token
    updater = Updater(TOKEN)

    # Get the dispatcher to register handlers
    dispatcher = updater.dispatcher

    # Register the command handler
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
