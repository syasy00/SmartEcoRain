<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
require_once("dbconnect.php");

// Get JSON data from POST
$data = json_decode(file_get_contents('php://input'), true);

if (!$data) {
    http_response_code(400);
    die("No data received");
}

$temperature  = isset($data['temperature']) ? floatval($data['temperature']) : null;
$humidity     = isset($data['humidity'])    ? floatval($data['humidity'])    : null;
$water_level  = isset($data['water_level']) ? floatval($data['water_level']) : null;
$rain_sensor  = isset($data['rain_sensor']) ? intval($data['rain_sensor'])   : null;
$relay_status = isset($data['relay_status']) ? $data['relay_status'] : "OFF";
$mode         = isset($data['mode']) ? $data['mode'] : "AUTO";

// Insert all fields!
$stmt = $conn->prepare(
    "INSERT INTO sensor_data (temperature, humidity, water_level, rain_sensor, relay_status, mode) VALUES (?, ?, ?, ?, ?, ?)"
);
$stmt->bind_param("dddiss", $temperature, $humidity, $water_level, $rain_sensor, $relay_status, $mode);

if ($stmt->execute()) {
    echo "OK";
} else {
    http_response_code(500);
    echo "DB error: " . $conn->error;
}

$stmt->close();
$conn->close();
?>
