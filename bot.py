import os
import telebot
import yt_dlp

# Initialize bot with Telegram token from environment variables
BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
bot = telebot.TeleBot(BOT_TOKEN)

# Set yt-dlp options
ydl_opts = {
    'format': 'best',
    'outtmpl': 'downloads/%(title)s.%(ext)s',
}

# Start command handler
@bot.message_handler(commands=['start'])
def send_welcome(message):
    bot.reply_to(message, "Welcome! Send me a Douyin or TikTok link, and I'll download the HD video for you.")

# Handle messages containing URLs
@bot.message_handler(func=lambda message: True)
def handle_url(message):
    url = message.text
    if "douyin" in url or "tiktok" in url:
        bot.reply_to(message, "Downloading video... Please wait.")
        download_video(url, message)
    else:
        bot.reply_to(message, "Please send a valid Douyin or TikTok URL.")

def download_video(url, message):
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            file_name = ydl.prepare_filename(info)
            send_video(file_name, message)
    except Exception as e:
        bot.reply_to(message, f"An error occurred: {e}")

def send_video(file_name, message):
    with open(file_name, 'rb') as video:
        bot.send_video(message.chat.id, video)
    os.remove(file_name)  # Clean up downloaded file

if __name__ == "__main__":
    bot.polling()
