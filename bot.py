import logging
import os
from aiogram import Bot, Dispatcher, executor, types
from yt_dlp import YoutubeDL
import requests

# Initialize the bot and dispatcher
TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
bot = Bot(token=TOKEN)
dp = Dispatcher(bot)

logging.basicConfig(level=logging.INFO)

def download_video(url):
    ydl_opts = {
        'format': 'bestvideo+bestaudio/best',
        'noplaylist': True,
        'outtmpl': '%(title)s.%(ext)s',
        'quiet': True
    }
    with YoutubeDL(ydl_opts) as ydl:
        info_dict = ydl.extract_info(url, download=False)
        video_url = ydl.prepare_filename(info_dict)
        ydl.download([url])
        return video_url

@dp.message_handler(commands=['start', 'help'])
async def send_welcome(message: types.Message):
    await message.reply("Hi! Send me a Douyin/TikTok video link, and I'll download it in HD for you.")

@dp.message_handler()
async def download_douyin_video(message: types.Message):
    url = message.text
    if 'douyin' in url or 'tiktok' in url:
        await message.reply("Downloading your video, please wait...")
        try:
            video_path = download_video(url)
            with open(video_path, 'rb') as video:
                await message.reply_video(video)
        except Exception as e:
            await message.reply(f"Failed to download video. Error: {e}")
    else:
        await message.reply("Please send a valid Douyin or TikTok video URL.")

if __name__ == '__main__':
    executor.start_polling(dp, skip_updates=True)
