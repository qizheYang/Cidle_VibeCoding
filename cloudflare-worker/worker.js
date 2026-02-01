/**
 * Cidle API Proxy - Cloudflare Worker
 *
 * This worker acts as a secure proxy between your Flutter web app and OpenAI's API.
 * Your OpenAI API key is stored securely as a Cloudflare secret and never exposed to clients.
 *
 * Deploy this to Cloudflare Workers, then set your OPENAI_API_KEY as a secret.
 */

const OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions';

// CORS headers for your domain
const corsHeaders = {
  'Access-Control-Allow-Origin': '*', // In production, change to your specific domain: 'https://yangqizhe.com'
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

// Handle CORS preflight requests
function handleOptions(request) {
  return new Response(null, {
    headers: corsHeaders,
  });
}

// Pinyin lookup endpoint
async function handlePinyin(request, env) {
  const body = await request.json();
  const characters = body.characters;

  if (!characters) {
    return new Response(JSON.stringify({ error: 'Missing characters' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const openAiResponse = await fetch(OPENAI_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: 'gpt-3.5-turbo',
      messages: [
        {
          role: 'system',
          content: `You are a Chinese pinyin expert. For each Chinese character, return its pinyin.
Rules:
- Return ONLY pinyin syllables separated by single spaces
- Use uppercase letters only (A-Z)
- No tone marks, no numbers, no punctuation, no quotes
- One syllable per character
- Use V for ü (e.g., 女 = NV, 绿 = LV)

Examples:
你好 → NI HAO
电脑 → DIAN NAO
学习 → XUE XI
旅游 → LV YOU`
        },
        {
          role: 'user',
          content: characters
        }
      ],
      max_tokens: 50,
      temperature: 0,
    }),
  });

  const data = await openAiResponse.json();

  return new Response(JSON.stringify(data), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// Random word generation endpoint
async function handleRandomWord(request, env) {
  const body = await request.json();
  const length = body.length || 2;
  const exclude = body.exclude || [];

  const wordType = length === 4 ? '成语(4字成语)' : `常用词语(${length}个字)`;
  const excludePrompt = exclude.length > 0
    ? `不要使用这些词：${exclude.join('、')}。`
    : '';

  const openAiResponse = await fetch(OPENAI_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: 'gpt-3.5-turbo',
      messages: [
        {
          role: 'system',
          content: `你是中文词汇专家。请生成一个随机的、常用的中文${wordType}。${excludePrompt}只返回汉字，不要拼音或解释。选择有趣且多样化的词汇。`
        },
        {
          role: 'user',
          content: `给我一个随机的中文${wordType}，只要汉字。`
        }
      ],
      max_tokens: 20,
      temperature: 1.2,
    }),
  });

  const data = await openAiResponse.json();
  const content = data.choices?.[0]?.message?.content;

  // Extract Chinese characters only
  const word = content ? content.replace(/[^\u4e00-\u9fff]/g, '') : null;

  return new Response(JSON.stringify({ word }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// Hints generation endpoint
async function handleHints(request, env) {
  const body = await request.json();
  const characters = body.characters;
  const isIdiom = body.isIdiom || false;

  if (!characters) {
    return new Response(JSON.stringify({ error: 'Missing characters' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const systemPrompt = isIdiom
    ? `你是一个成语猜谜游戏的提示生成器。为给定成语生成3个递进式提示，帮助玩家逐步猜出答案。

提示要求（必须按顺序，逐渐具体）:

第一个提示 - 基础分类:
- 说明成语的感情色彩（褒义/贬义/中性）
- 或说明成语的用法（形容人/形容事/形容物）
- 例如："这是一个褒义成语，常用来赞美人"

第二个提示 - 来源背景:
- 说明成语的出处类型（历史典故/寓言故事/神话传说/古代战争/文学作品）
- 如果有具体出处，可以提及书名或时代
- 例如："来自战国时期的一个寓言故事"、"出自《庄子》"

第三个提示 - 故事线索:
- 描述成语典故中的关键情节或画面
- 提及故事中的人物行为或场景，但不直接解释成语含义
- 例如："故事中有人守在一棵树旁，等待某种动物"、"涉及一个人在船上刻记号"

严格禁止:
- 绝对不能使用成语中的任何一个字
- 不能直接解释成语的现代含义
- 不能给出成语的同义词

输出格式: 每行一个提示，共3行，不要编号。每个提示10-25个中文字。`
    : `你是一个词语猜谜游戏的提示生成器。为给定词语生成3个递进式提示。

提示类型（必须按此顺序）:
1. 【词性或大类】如: "这是一个名词"、"这是一个动词"、"属于自然现象"、"与情感相关"
2. 【使用场景】如: "在学校常见"、"工作中会用到"、"购物时涉及"、"与天气相关"
3. 【具体联想】给出一个具体但不直接的线索。如: "早晨起床后会做"、"需要用眼睛"、"与声音有关"

严格禁止:
- 不得使用词语中的任何一个字
- 不得直接解释词语含义
- 不得给出同义词
- 三个提示必须从不同角度出发

输出格式: 每行一个提示，共3行，不要编号。每个提示6-12个中文字。`;

  const openAiResponse = await fetch(OPENAI_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: 'gpt-3.5-turbo',
      messages: [
        {
          role: 'system',
          content: systemPrompt
        },
        {
          role: 'user',
          content: `请为"${characters}"生成3个递进式提示`
        }
      ],
      max_tokens: isIdiom ? 200 : 120,
      temperature: 0.7,
    }),
  });

  const data = await openAiResponse.json();
  const content = data.choices?.[0]?.message?.content;

  // Parse hints from response
  let hints = [];
  if (content) {
    hints = content.trim().split('\n')
      .map(line => line.trim())
      .filter(line => line.length > 0)
      .map(line => line.replace(/^(提示)?[\d]+[.、:：\s]*/, '').trim())
      .slice(0, 3);
  }

  return new Response(JSON.stringify({ hints }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// Main request handler
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return handleOptions(request);
    }

    // Check for API key
    if (!env.OPENAI_API_KEY) {
      return new Response(JSON.stringify({ error: 'API key not configured' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Route requests
    try {
      if (path === '/pinyin' && request.method === 'POST') {
        return await handlePinyin(request, env);
      } else if (path === '/random-word' && request.method === 'POST') {
        return await handleRandomWord(request, env);
      } else if (path === '/hints' && request.method === 'POST') {
        return await handleHints(request, env);
      } else if (path === '/health') {
        return new Response(JSON.stringify({ status: 'ok' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      } else {
        return new Response(JSON.stringify({ error: 'Not found' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    } catch (error) {
      return new Response(JSON.stringify({ error: 'Internal server error' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
  },
};
