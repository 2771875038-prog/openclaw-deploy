import os
import logging
import asyncio
import ccxt.async_support as ccxt
import google.generativeai as genai
from telegram import Update
from telegram.ext import ApplicationBuilder, ContextTypes, CommandHandler

# Configure logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Configuration
CHECK_INTERVAL = int(os.getenv('CHECK_INTERVAL', 10))
THRESHOLD_PERCENT = float(os.getenv('THRESHOLD_PERCENT', 0.5))
TARGET_PAIRS = os.getenv('TARGET_PAIRS', 'BTC/USDT,ETH/USDT').split(',')
TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
TELEGRAM_CHAT_ID = os.getenv('TELEGRAM_CHAT_ID')
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')

if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
    logger.error("TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is missing!")
    exit(1)

# Configure Gemini
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel('gemini-pro')
    logger.info("Gemini AI Configured.")
else:
    model = None
    logger.warning("Gemini API Key not found. AI features disabled.")

class ArbitrageBot:
    def __init__(self):
        self.binance = ccxt.binance()
        self.okx = ccxt.okx()
        
    async def shutdown(self):
        await self.binance.close()
        await self.okx.close()

    async def fetch_price(self, exchange, symbol):
        try:
            ticker = await exchange.fetch_ticker(symbol)
            return ticker['last']
        except Exception as e:
            logger.error(f"Error fetching {symbol} from {exchange.id}: {e}")
            return None

    async def get_arbitrage_data(self):
        results = []
        for symbol in TARGET_PAIRS:
            symbol = symbol.strip()
            binance_price = await self.fetch_price(self.binance, symbol)
            okx_price = await self.fetch_price(self.okx, symbol)

            if binance_price and okx_price:
                diff = abs(binance_price - okx_price)
                mean_price = (binance_price + okx_price) / 2
                diff_percent = (diff / mean_price) * 100
                results.append({
                    'symbol': symbol,
                    'binance': binance_price,
                    'okx': okx_price,
                    'diff_percent': diff_percent
                })
        return results

    async def analyze_market(self, data):
        if not model:
            return "🤖 AI Analysis unavailable (No Key)."
        
        prompt = (
            f"Act as a professional crypto arbitrage trader. Analyze these opportunities:\n"
            f"{data}\n"
            f"Provide a short, witty, and actionable summary (max 3 sentences) for a trader."
        )
        try:
            response = await model.generate_content_async(prompt)
            return response.text
        except Exception as e:
            logger.error(f"Gemini Error: {e}")
            return "🤖 AI Analysis failed temporarily."

bot_instance = ArbitrageBot()

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    ai_status = "enabled ✅" if model else "disabled ❌"
    await context.bot.send_message(
        chat_id=update.effective_chat.id, 
        text=f"OpenClaw Arbitrage Monitor Started! 🚀\nAI Analysis: {ai_status}\nI will alert you when price difference > {THRESHOLD_PERCENT:.2f}%."
    )

async def status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await context.bot.send_message(chat_id=update.effective_chat.id, text="🔍 Checking current prices...")
    data = await bot_instance.get_arbitrage_data()
    
    if not data:
        await context.bot.send_message(chat_id=update.effective_chat.id, text="Failed to fetch data.")
        return

    msg = "📊 **Current Market Status**:\n"
    for item in data:
        icon = "🟢" if item['diff_percent'] < THRESHOLD_PERCENT else "🔴"
        msg += (
            f"{icon} {item['symbol']}\n"
            f"   Binance: {item['binance']}\n"
            f"   OKX: {item['okx']}\n"
            f"   Diff: {item['diff_percent']:.3f}%\n"
        )
    
    # AI Analysis on demand
    if model:
        await context.bot.send_message(chat_id=update.effective_chat.id, text=msg)
        analysis = await bot_instance.analyze_market(data)
        await context.bot.send_message(chat_id=update.effective_chat.id, text=f"🤖 **AI Insight**:\n{analysis}")
    else:
        await context.bot.send_message(chat_id=update.effective_chat.id, text=msg)

async def check_arbitrage_job(context: ContextTypes.DEFAULT_TYPE):
    data = await bot_instance.get_arbitrage_data()
    
    for item in data:
        logger.info(f"Checked {item['symbol']}: Diff={item['diff_percent']:.3f}%")
        
        if item['diff_percent'] > THRESHOLD_PERCENT:
            message = (
                f"🚨 **Arbitrage Opportunity!**\n"
                f"Symbol: {item['symbol']}\n"
                f"Binance: {item['binance']}\n"
                f"OKX: {item['okx']}\n"
                f"Spread: {item['diff_percent']:.3f}% 🚀"
            )
            await context.bot.send_message(chat_id=TELEGRAM_CHAT_ID, text=message)
            
            # Optional: Add AI analysis to alert if spread is significant (>1%)
            if model and item['diff_percent'] > 1.0:
                 analysis = await bot_instance.analyze_market([item])
                 await context.bot.send_message(chat_id=TELEGRAM_CHAT_ID, text=f"🤖 **Quick Insight**: {analysis}")

async def post_shutdown(application: ApplicationBuilder):
    await bot_instance.shutdown()

if __name__ == '__main__':
    application = ApplicationBuilder().token(TELEGRAM_BOT_TOKEN).post_shutdown(post_shutdown).build()
    
    start_handler = CommandHandler('start', start)
    status_handler = CommandHandler('status', status)
    
    application.add_handler(start_handler)
    application.add_handler(status_handler)
    
    # Run the check every X seconds
    job_queue = application.job_queue
    job_queue.run_repeating(check_arbitrage_job, interval=CHECK_INTERVAL, first=5)
    
    logger.info("Bot is polling...")
    application.run_polling()
