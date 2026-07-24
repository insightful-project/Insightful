<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$name = $_GET['name'] ?? '';
if (!$name) {
    echo json_encode([]);
    exit;
}

$file = __DIR__ . '/../data/' . basename($name) . '.json';
if (!is_file($file)) {
    echo json_encode([]);
    exit;
}

$data = json_decode(file_get_contents($file), true);
echo json_encode(array_slice($data ?? [], -60));
