/**
 * Cloudflare Worker for OpenAI Chat API Proxy
 * Provides the same functionality as main.py but runs on Cloudflare's edge
 */

// Supported OpenAI models
const SUPPORTED_MODELS = [
  'gpt-4o',
  'gpt-4o-mini', 
  'gpt-4-turbo',
  'gpt-4',
  'gpt-3.5-turbo',
  'gpt-4.1-nano'
];

// CORS headers for browser requests
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const startTime = Date.now();
    
    try {
      // Handle CORS preflight
      if (request.method === 'OPTIONS') {
        return new Response(null, { headers: corsHeaders });
      }
      
      let response;
      
      // Route requests
      if (request.method === 'GET') {
        response = await handleGet(url.pathname);
      } else if (request.method === 'POST') {
        response = await handlePost(request, url.pathname, env);
      } else {
        response = new Response('Method not allowed', { status: 405 });
      }
      
      const duration = Date.now() - startTime;
      console.log(`${request.method} ${url.pathname} - ${response.status} (${duration}ms)`);
      
      return response;
      
    } catch (error) {
      const duration = Date.now() - startTime;
      console.error(`${request.method} ${url.pathname} - ERROR (${duration}ms):`, error.message);
      return new Response('Internal Server Error', { 
        status: 500,
        headers: corsHeaders
      });
    }
  }
};

async function handleGet(pathname) {
  if (pathname === '/') {
    const response = {
      message: "Cheat CLI API is running on Cloudflare Workers",
      version: "2.0",
      platform: "cloudflare-workers"
    };
    return new Response(JSON.stringify(response), {
      headers: { 
        'Content-Type': 'application/json',
        ...corsHeaders 
      }
    });
  }
  
  if (pathname === '/health') {
    const response = { status: "healthy" };
    return new Response(JSON.stringify(response), {
      headers: { 
        'Content-Type': 'application/json',
        ...corsHeaders 
      }
    });
  }
  
  if (pathname === '/models') {
    const response = { 
      models: SUPPORTED_MODELS.map(model => ({
        id: model,
        name: model
      }))
    };
    return new Response(JSON.stringify(response), {
      headers: { 
        'Content-Type': 'application/json',
        ...corsHeaders 
      }
    });
  }
  
  return new Response('Not Found', { 
    status: 404,
    headers: corsHeaders
  });
}

async function handlePost(request, pathname, env) {
  if (pathname !== '/chat') {
    return new Response('Not Found', { 
      status: 404,
      headers: corsHeaders
    });
  }
  
  try {
    const requestData = await request.json();
    const model = requestData.model || 'gpt-4o-mini';
    const messages = requestData.messages || [];
    
    // Validate model
    if (!SUPPORTED_MODELS.includes(model)) {
      console.log(`Unsupported model requested: ${model}`);
      return new Response(`Unsupported model: ${model}. Supported models: ${SUPPORTED_MODELS.join(', ')}`, { 
        status: 400,
        headers: corsHeaders
      });
    }
    
    // Extract user message for logging
    const userMessage = messages.length > 0 ? messages[messages.length - 1]?.content || '' : '';
    const truncatedUserMessage = userMessage.length > 100 ? userMessage.slice(0, 100) + '...' : userMessage;
    
    // Get OpenAI API key from environment variables
    const openaiApiKey = env.OPENAI_API_KEY;
    if (!openaiApiKey) {
      console.error('OPENAI_API_KEY not configured');
      return new Response('OPENAI_API_KEY not configured', { 
        status: 500,
        headers: corsHeaders
      });
    }
    
    // Prepare OpenAI API request (no streaming)
    const openaiRequest = {
      model: model,
      messages: messages,
      stream: false
    };
    
    // Call OpenAI API
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openaiApiKey}`
      },
      body: JSON.stringify(openaiRequest)
    });
    
    if (!openaiResponse.ok) {
      const errorText = await openaiResponse.text();
      console.error(`OpenAI API error (${openaiResponse.status}):`, errorText);
      return new Response(`OpenAI API error: ${openaiResponse.status}`, { 
        status: openaiResponse.status,
        headers: corsHeaders
      });
    }
    
    // Get the complete response and return it immediately
    const data = await openaiResponse.json();
    const content = data.choices[0].message.content;
    const truncatedResponse = content.length > 100 ? content.slice(0, 100) + '...' : content;
    
    // Log the conversation
    console.log(`User: "${truncatedUserMessage}" | AI: "${truncatedResponse}"`);
    
    return new Response(content, {
      headers: {
        'Content-Type': 'text/plain',
        ...corsHeaders
      }
    });
    
  } catch (error) {
    console.error('Chat request error:', error.message);
    return new Response(`Error: ${error.message}`, { 
      status: 500,
      headers: corsHeaders
    });
  }
}


