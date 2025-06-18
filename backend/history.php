<?php
require_once("dbconnect.php");

// Fetch last 30 records (adjust LIMIT as needed)
$sql = "SELECT id, water_level, temperature, humidity, rain_sensor, relay_status, mode, timestamp 
        FROM sensor_data 
        ORDER BY id DESC 
        LIMIT 30";
$result = $conn->query($sql);

$data = [];
while ($row = $result->fetch_assoc()) {
    $data[] = [
        "id"          => intval($row['id']),
        "tank_level"  => floatval($row['water_level']),
        "temperature" => floatval($row['temperature']),
        "humidity"    => floatval($row['humidity']),
        "rain_collected" => ($row['rain_sensor'] > 1000),  // true/false
        "relay_status"   => $row['relay_status'],           // "ON" or "OFF"
        "mode"           => $row['mode'],                  // "AUTO" or "MANUAL"
        "timestamp"      => $row['timestamp']
    ];
}
header('Content-Type: application/json');
echo json_encode($data);
$conn->close();
?>
