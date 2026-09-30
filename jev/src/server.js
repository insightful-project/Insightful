import { createServer } from 'http';
import { zodSchema } from './schemas.js';

const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;
const PORT = parseInt(process.env.JEV_PORT || '4002', 10);
const OPENROUTER_URL = 'https://openrouter.ai/api/alpha/decisions';
const MODEL_DEFAULT = 'typesafe/jev-1.13';
const THRESHOLDS_DEFAULT = { act: 0.9, reroute: 0.7 };

if (!OPENROUTER_API_KEY) {
    console.error('OPENROUTER_API_KEY not set');
    process.exit(1);
}

function log(level, message, meta = {}) {
    console.log(JSON.stringify({ level, message, meta, timestamp: new Date().toISOString() }));
}

function validateInput(body) {
    const result = zodSchema.safeParse(body);
    if (!result.success) {
        return { valid: false, errors: result.error.flatten() };
    }
    return { valid: true, data: result.data };
}

async function callJev(payload) {
    const response = await fetch('https://openrouter.ai/api/alpha/decisions', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${OPENROUTER_API_KEY}`,
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://insightful-projects.com',
            'X-Title': 'Insightful Decision Service',
        },
        body: JSON.stringify(payload),
    });

    if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Jev ${response.status}: ${errorText}`);
    }

    return response.json();
}

function computeVerdict(answers, thresholds) {
    const lowConfidence = [];

    for (const [key, answer] of Object.entries(answers || {})) {
        if (answer.type === 'noul') {
            const conf = Math.max(answer.noul, 1 - answer.noul);
            if (conf < (thresholds.reroute || 0.7)) lowConfidence.push(key);
        }
        else if (answer.type === 'choice' || answer.type === 'score') {
            if ((answer.confidence || 0) < (thresholds.reroute || 0.7)) lowConfidence.push(key);
        }
    }

    let verdict = 'human';
    if (lowConfidence.length === 0 && Object.keys(answers).length > 0) {
        const allHigh = Object.values(answers).every(a => {
            if (a.type === 'noul') return Math.max(a.noul, 1 - a.noul) >= (thresholds.act || 0.9);
            return (a.confidence || 0) >= (thresholds.act || 0.9);
        });
        verdict = allHigh ? 'act' : 'reroute';
    }
    else if (lowConfidence.length > 0 && Object.keys(answers).length > lowConfidence.length) {
        verdict = 'reroute';
    }

    return { verdict, lowConfidence };
}

const server = createServer(async (req, res) => {
    const start = Date.now();
    const correlationId = crypto.randomUUID();

    res.setHeader('Content-Type', 'application/json');
    res.setHeader('X-Correlation-Id', correlationId);

    if (req.url === '/health' && req.method === 'GET') {
        res.writeHead(200);
        res.end(JSON.stringify({ status: 'ok', service: 'jev-decision', timestamp: new Date().toISOString() }));
        return;
    }

    if (req.url === '/decision' && req.method === 'POST') {
        let body = '';
        for await (const chunk of req) body += chunk;

        let input;
        try {
            input = JSON.parse(body);
        } catch {
            res.writeHead(400);
            res.end(JSON.stringify({ status: 'error', error: 'Invalid JSON' }));
            return;
        }

        const validation = zodSchema.safeParse(input);
        if (!validation.success) {
            res.writeHead(400);
            res.end(JSON.stringify({ status: 'error', error: 'Validation failed', details: validation.error.flatten() }));
            return;
        }

        const data = validation.data;
        const model = data.model || 'typesafe/jev-1.13';
        const thresholds = data.thresholds || { act: 0.9, reroute: 0.7 };

        try {
            const payload = {
                model,
                state: data.state || { objective: data.objective },
                questions: data.questions || {},
            };

            log('info', 'Calling Jev', { model, questionsCount: Object.keys(payload.questions).length, correlationId });

            const response = await fetch('https://openrouter.ai/api/alpha/decisions', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${OPENROUTER_API_KEY}`,
                    'Content-Type': 'application/json',
                    'HTTP-Referer': 'https://insightful-projects.com',
                    'X-Title': 'Insightful Decision Service',
                },
                body: JSON.stringify(payload),
            });

            if (!response.ok) {
                const errorText = await response.text();
                log('error', 'Jev call failed', { status: response.status, error: errorText, correlationId });
                res.writeHead(502);
                res.end(JSON.stringify({ status: 'error', error: `Jev ${response.status}`, details: errorText }));
                return;
            }

            const data = await response.json();

            const answers = {};
            for (const [key, answer] of Object.entries(data.answers || {})) {
                if (answer.type === 'noul') answers[key] = { type: 'noul', noul: answer.noul };
                else if (answer.type === 'choice') answers[key] = { type: 'choice', choice: answer.choice, confidence: answer.confidence };
                else if (answer.type === 'score') answers[key] = { type: 'score', score: answer.score, confidence: answer.confidence };
            }

            const { verdict, lowConfidence } = computeVerdict(answers, thresholds);

            const result = {
                verdict,
                answers,
                lowConfidence,
                model: data.model || model,
                cost: data.usage?.cost || 0,
                usage: { input_tokens: data.usage?.input_tokens || 0, output_tokens: data.usage?.output_tokens || 0 },
            };

            log('info', 'Decision complete', { verdict, cost: result.cost, correlationId });
            res.writeHead(200);
            res.end(JSON.stringify(result));

        } catch (err) {
            log('error', 'Decision failed', { error: err.message, correlationId });
            res.writeHead(500);
            res.end(JSON.stringify({ status: 'error', error: err.message }));
        }
        return;
    }

    res.writeHead(404);
    res.end(JSON.stringify({ status: 'error', error: 'Not found' }));
});

server.listen(PORT, '0.0.0.0', () => {
    log('info', `Jev Decision Service listening on port ${PORT}`);
});