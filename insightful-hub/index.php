<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Insightful Hub</title>
    <link rel="stylesheet" href="style.css">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
    <script src="https://unpkg.com/vue@3/dist/vue.global.prod.js"></script>
</head>
<body>
    <div id="app">
        <header>
            <h1>Insightful Hub</h1>
            <div class="header-meta">
                <span class="service-count">{{ totalCount }} services</span>
                <span class="last-updated" v-if="lastUpdated">{{ lastUpdated }}</span>
                <button class="refresh-btn" @click="fetchStatus" :class="{ spinning: refreshing }">&#x21bb;</button>
            </div>
        </header>

        <transition-group name="toast">
            <div v-for="toast in toasts" :key="toast.id" class="toast" :class="toast.type" @click="dismissToast(toast.id)">
                <span class="toast-dot" :class="toast.type"></span>
                <span class="toast-msg">{{ toast.message }}</span>
            </div>
        </transition-group>

        <div class="sections" v-if="Object.keys(groups).length">
            <div v-for="(svcs, group) in groups" :key="group" class="section">
                <div class="section-header" @click="toggleGroup(group)">
                    <span class="chevron" :class="{ open: openGroups[group] }">&#x25B6;</span>
                    <h2>{{ groupLabel(group) }}</h2>
                    <span class="section-count">{{ groupCount(svcs) }}</span>
                </div>
                <transition name="collapse">
                    <div v-show="openGroups[group]" class="grid">
                        <div v-for="svc in svcs" :key="svc.name" class="card"
                             :class="{ offline: svc.status === 'error', expanded: expanded === svc.name }"
                             @click="toggleExpand(svc)">
                            <div class="card-header">
                                <span class="dot" :class="statusDot(svc)" :data-pulsing="svc._pulsing"></span>
                                <span class="name">{{ svc.name }}</span>
                                <span class="card-status" :class="svc.status">{{ statusLabel(svc) }}</span>
                            </div>
                            <div class="card-body">
                                <span class="latency" v-if="svc.latency !== undefined && svc.status !== 'loading'">{{ svc.latency }}ms</span>
                                <span class="url">{{ svc.url }}</span>
                            </div>

                            <transition name="detail">
                                <div v-if="expanded === svc.name" class="detail-panel" @click.stop>
                                    <div class="detail-stats">
                                        <div class="stat"><span class="stat-label">Uptime</span><span class="stat-value">{{ svc._uptime || '—' }}</span></div>
                                        <div class="stat"><span class="stat-label">Last check</span><span class="stat-value">{{ formatTime(svc.time) }}</span></div>
                                        <div class="stat"><span class="stat-label">HTTP</span><span class="stat-value">{{ svc.httpCode || '—' }}</span></div>
                                    </div>

                                    <div class="sparkline-wrap" v-if="history[svc.name] && history[svc.name].length > 1">
                                        <div class="sparkline-label">Latency (last 60 checks)</div>
                                        <svg :viewBox="'0 0 ' + sparkViewBox(svc)" class="sparkline-svg">
                                            <polyline :points="sparkPoints(svc)" fill="none" stroke="var(--accent)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
                                        </svg>
                                    </div>

                                    <div class="detail-actions">
                                        <button class="btn" @click="openUrl(svc.url)">Open Service</button>
                                        <button class="btn" v-if="grafanaLogUrl(svc)" @click="openUrl(grafanaLogUrl(svc))">View Logs</button>
                                        <button class="btn btn-ghost" @click="copyLogCmd(svc)">Copy Log Cmd</button>
                                    </div>
                                </div>
                            </transition>
                        </div>
                    </div>
                </transition>
            </div>
        </div>

        <!-- ── Databases Section ── -->
        <div class="section" v-if="databases.length">
            <div class="section-header" @click="toggleGroup('_databases')">
                <span class="chevron" :class="{ open: openGroups['_databases'] }">&#x25B6;</span>
                <h2>Databases</h2>
                <span class="section-count">{{ databases.length }}</span>
            </div>
            <transition name="collapse">
                <div v-show="openGroups['_databases']" class="grid">
                    <div v-for="db in databases" :key="db.label" class="card card--db">
                        <div class="card-header">
                            <span class="dot green"></span>
                            <span class="name">{{ db.label }}</span>
                            <span class="stack-tag">{{ db.stack }}</span>
                        </div>
                        <div class="card-body">
                            <span class="url">{{ db.host }}:{{ db.port }}</span>
                            <span class="db-meta">DB: {{ db.name }} · User: {{ db.user }}</span>
                            <span class="db-meta pw-hint">pw: {{ db.pwSource }}</span>
                            <button class="btn btn-ghost btn--small" @click.stop="copyDbConn(db)">Copy Connection</button>
                        </div>
                    </div>
                </div>
            </transition>
        </div>

        <div v-else class="loading-screen">
            <div class="loading-dot"></div>
            <span>Loading services...</span>
        </div>

        <!-- ── Footer ── -->
        <div class="footer-bar">
            <span>Insightful Hub · <a href="https://github.com/Insightful-Project" target="_blank">GitHub</a></span>
            <span class="footer-ts" v-if="lastUpdated">Last check: {{ lastUpdated }}</span>
        </div>
    </div>

    <script>
    const { createApp, ref, reactive, computed, watch, onMounted, nextTick } = Vue;

    const GROUP_LABELS = {
        applications: 'Applications',
        ai: 'AI',
        automation: 'Automation',
        infrastructure: 'Infrastructure',
    };

    createApp({
        setup() {
            const services = ref([]);
            const databases = ref([]);
            const lastUpdated = ref('');
            const refreshing = ref(false);
            const expanded = ref(null);
            const history = reactive({});
            const openGroups = reactive({ applications: true, ai: true, automation: true, infrastructure: true });
            const toasts = ref([]);
            let toastId = 0;
            let prevStatus = {};

            const groups = computed(() => {
                const map = {};
                for (const svc of services.value) {
                    const g = svc.group || 'other';
                    if (!map[g]) map[g] = [];
                    map[g].push(svc);
                }
                return map;
            });

            const totalCount = computed(() => services.value.length);

            function groupLabel(g) { return GROUP_LABELS[g] || g; }

            function groupCount(svcs) {
                const on = svcs.filter(s => s.status === 'ok').length;
                return `${on}/${svcs.length}`;
            }

            function statusDot(svc) {
                if (svc.status === 'ok') return 'green';
                if (svc.status === 'loading') return 'yellow';
                return 'red';
            }

            function statusLabel(svc) {
                if (svc.status === 'ok') return 'Online';
                if (svc.status === 'loading') return 'Checking...';
                return 'Offline';
            }

            function formatTime(iso) {
                if (!iso) return '';
                const d = new Date(iso);
                return d.toLocaleTimeString();
            }

            function toggleGroup(g) {
                openGroups[g] = !openGroups[g];
            }

            async function toggleExpand(svc) {
                if (expanded.value === svc.name) {
                    expanded.value = null;
                    return;
                }
                expanded.value = svc.name;
                if (!history[svc.name]) {
                    try {
                        const res = await fetch(`/api/history.php?name=${encodeURIComponent(svc.name)}`);
                        history[svc.name] = await res.json();
                    } catch (e) {
                        history[svc.name] = [];
                    }
                }
            }

            function sparkViewBox(svc) {
                const pts = history[svc.name];
                if (!pts || pts.length < 2) return '0 0 100 40';
                const w = Math.max(pts.length * 2, 100);
                return `0 0 ${w} 40`;
            }

            function sparkPoints(svc) {
                const pts = history[svc.name];
                if (!pts || pts.length < 2) return '0,20 100,20';
                const vals = pts.map(p => p.latency || 0);
                const max = Math.max(...vals, 1);
                const w = Math.max(vals.length * 2, 100);
                return vals.map((v, i) => {
                    const x = i * (w / Math.max(vals.length - 1, 1));
                    const y = 40 - (v / max) * 36;
                    return `${x.toFixed(1)},${y.toFixed(1)}`;
                }).join(' ');
            }

            function openUrl(url) {
                window.open(url, '_blank');
            }

            let logCmdTimeout;
            function copyLogCmd(svc) {
                const product = ({
                    'Vue': 'life-os', 'API': 'life-os', 'CloudBeaver': 'life-os',
                    'Redis': 'redis',
                    'Loki': 'observability', 'Grafana': 'observability',
                    'n8n': 'n8n',
                    'codeSpace Java': 'codespace',
                    'ntfy': 'odysseus', 'Odysseus': 'odysseus', 'ChromaDB': 'odysseus', 'SearXNG': 'odysseus',
                    'Ollama': 'ollama',
                    'Qdrant': 'qdrant',
                    'code-server': 'code-server',
                    'NPM': 'npm',
                    'Hub': 'hub',
                })[svc.name] || svc.name.toLowerCase().replace(/\s+/g, '-');
                const cmd = `./logs.sh ${product}`;
                navigator.clipboard?.writeText(cmd);
                const btn = event?.target;
                if (btn) { btn.textContent = 'Copied!'; clearTimeout(logCmdTimeout); logCmdTimeout = setTimeout(() => btn.textContent = 'Copy Log Cmd', 2000); }
            }

            // Map service name → container name → Grafana Loki explore URL
            function grafanaLogUrl(svc) {
                const containers = {
                    'API': 'lifeos-api-nest',
                    'Vue': 'lifeos-vue-app',
                    'Redis': 'insightful-redis',
                    'Loki': 'insightful-loki',
                    'Grafana': 'insightful-grafana',
                    'CloudBeaver': 'lifeos-cloudbeaver',
                    'codeSpace Java': 'codespace-java',
                    'n8n': 'n8n',
                    'ntfy': 'odysseus-ntfy',
                    'Odysseus': 'odysseus',
                    'Ollama': 'insightful-ollama',
                    'ChromaDB': 'odysseus-chromadb',
                    'SearXNG': 'odysseus-searxng',
                    'Qdrant': 'insightful-mem0-qdrant',
                    'code-server': 'insightful-code-server',
                    'NPM': 'npm',
                    'Hub': 'insightful-hub',
                };
                const cname = containers[svc.name];
                if (!cname) return null;
                const expr = encodeURIComponent(`{container_name="${cname}"}`);
                return `http://localhost:3000/explore?orgId=1&left=${encodeURIComponent('{"datasource":"Loki","queries":[{"refId":"A","expr":"' + expr + '"}],"range":{"from":"now-1h","to":"now"}}')}`;
            }

            function copyDbConn(db) {
                const conn = `postgresql://${db.user}@${db.host}:${db.port}/${db.name}`;
                navigator.clipboard?.writeText(conn);
                addToast('ok', `Copied: ${conn}`);
            }

            function addToast(type, message) {
                const id = ++toastId;
                toasts.value.push({ id, type, message });
                setTimeout(() => dismissToast(id), 6000);
            }

            function dismissToast(id) {
                toasts.value = toasts.value.filter(t => t.id !== id);
            }

            async function fetchStatus() {
                refreshing.value = true;
                try {
                    const res = await fetch('/api/status.php');
                    const data = await res.json();
                    const oldMap = {};
                    for (const s of services.value) oldMap[s.name] = s.status;

                    for (const svc of data) {
                        svc._pulsing = false;
                        if (oldMap[svc.name] && oldMap[svc.name] !== 'loading' && oldMap[svc.name] !== svc.status) {
                            if (svc.status === 'error') {
                                svc._pulsing = true;
                                addToast('error', `${svc.name} went offline`);
                                setTimeout(() => svc._pulsing = false, 2000);
                            } else if (svc.status === 'ok') {
                                addToast('ok', `${svc.name} is back online`);
                            }
                        }
                    }
                    services.value = data;
                    lastUpdated.value = new Date().toLocaleTimeString();
                } catch (e) {}
                refreshing.value = false;
            }

            onMounted(async () => {
                try {
                    const cfg = await fetch('/services.json');
                    const list = await cfg.json();
                    services.value = list.map(s => ({ ...s, status: 'loading', latency: undefined }));
                } catch (e) {}
                try {
                    const dbRes = await fetch('/databases.json');
                    databases.value = await dbRes.json();
                } catch (e) {}
                fetchStatus();
                setInterval(fetchStatus, 15000);
            });

            return {
                services, databases, lastUpdated, refreshing, expanded, history, openGroups, toasts,
                groups, totalCount, groupLabel, groupCount, statusDot, statusLabel,
                formatTime, toggleGroup, toggleExpand, sparkViewBox, sparkPoints,
                openUrl, copyLogCmd, grafanaLogUrl, copyDbConn, addToast, dismissToast, fetchStatus,
            };
        }
    }).mount('#app');
    </script>
</body>
</html>
