import { start } from './index.js';

// 直接注入配置对象，跳过 toml 解析
const config = {
  gateway: {
    key: "AIzaSyCwjn8Tey4fxeNzmHNzKA9WF4vH6ixBIcA"
  },
  channels: {
    telegram: {
      bot_token: "8605005604:AAEpeE6N8fIruOBPRN842rO9YGMcMK48Utg",
      chat_id: "8363729701",
      enabled: true
    }
  }
};

console.log("🚀 正在绕过配置文件启动机器人...");
start(config).catch(err => {
    console.error("❌ 启动失败:", err);
});