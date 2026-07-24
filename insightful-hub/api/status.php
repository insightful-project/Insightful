<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$configPath = __DIR__ . '/../services.json';
$historyDir = __DIR__ . '/../data';

$services = json_decode(file_get_contents($configPath), true);
if (!$services) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to load services.json']);
    exit;
}

$results = [];
foreach ($services as $svc) {
    $healthUrl = $svc['health'] ?? '';
    if (!$healthUrl) {
        $results[] = [
            'name' => $svc['name'],
            'group' => $svc['group'] ?? '',
            'url' => $svc['url'],
            'status' => 'ok',
            'latency' => 0,
            'time' => date('c'),
        ];
        continue;
    }

    $start = microtime(true);
    $http_response_header = [];
    $ctx = stream_context_create(['http' => [
        'timeout' => 5,
        'method' => 'GET',
        'follow_location' => true,
        'ignore_errors' => true,
    ]]);
    $body = @file_get_contents($healthUrl, false, $ctx);
    $latency = round((microtime(true) - $start) * 1000);
    $httpCode = 0;
    if ($body !== false && !empty($http_response_header)) {
        $httpCode = (int)explode(' ', $http_response_header[0])[1];
    }

    $status = ($httpCode >= 200 && $httpCode < 400) ? 'ok' : 'error';

    $entry = [
        'name' => $svc['name'],
        'group' => $svc['group'] ?? '',
        'url' => $svc['url'],
        'status' => $status,
        'httpCode' => $httpCode,
        'latency' => $latency,
        'time' => date('c'),
    ];
    $results[] = $entry;

    $historyFile = "$historyDir/{$svc['name']}.json";
    $history = [];
    if (is_file($historyFile)) {
        $history = json_decode(file_get_contents($historyFile), true) ?? [];
    }
    $history[] = ['status' => $status, 'latency' => $latency, 'time' => $entry['time']];
    $history = array_slice($history, -240);
    file_put_contents($historyFile, json_encode($history));
}

echo json_encode($results, JSON_PRETTY_PRINT);
