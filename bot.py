import logging
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes, MessageHandler, filters
import yt_dlp

# Enable logging
logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                    level=logging.INFO)
logger = logging.getLogger(__name__)

# Telegram Bot Token
TOKEN = 'YOUR_TELEGRAM_BOT_TOKEN'

def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Send a message when the command /start is issued."""
    user = update.effective_user
    update.message.reply_markdown_v2(
        fr'Hi {user.mention_markdown_v2()}\! Welcome to the Video Downloader Bot\.\n'
        'Send me a video URL and I will download it for you\.',
    )

def download_video(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Download video from the provided URL."""
    url = update.message.text.strip()
    update.message.reply_text('Downloading video... This may take a while.')

    ydl_opts = {
        'format': 'bestvideo',
        'outtmpl': '%(title)s.%(ext)s',
        'noplaylist': True,
        'quiet': True,
        'postprocessors': [{
            'key': 'FFmpegVideoConvertor',
            'preferedformat': 'mp4',  # Convert to mp4 if necessary
        }]
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info_dict = ydl.extract_info(url, download=True)
            video_title = info_dict.get('title', 'downloaded_video')
            update.message.reply_text(f'✅ Video downloaded successfully: {video_title}.mp4')
    except Exception as e:
        logger.error(f'Error downloading video: {e}')
        update.message.reply_text('Failed to download video. Please check the URL and try again.')

def main() -> None:
    """Start the bot."""
    application = Application.builder().token(TOKEN).build()

    # on different commands - answer in Telegram
    application.add_handler(CommandHandler("start", start))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, download_video))

    # Run the bot until the user presses Ctrl-C
    application.run_polling()

if __name__ == '__main__':
    main()
