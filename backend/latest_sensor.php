<?php
require_once("dbconnect.php");

$sql = "SELECT * FROM sensor_data ORDER BY id DESC LIMIT 1";
$result = $conn->query($sql);

if ($row = $result->fetch_assoc()) {
    $response = [
        "tank_level"     => floatval($row['water_level']),
        "temperature"    => floatval($row['temperature']),
        "humidity"       => floatval($row['humidity']),
        "rain_collected" => ($row['rain_sensor'] > 1000),
        "relay_status"   => $row['relay_status'],    // ON/OFF
        "mode"           => $row['mode'],            // AUTO/MANUAL
        "timestamp"      => $row['timestamp']
    ];
    echo json_encode($response);
} else {
    echo json_encode([
        "tank_level" => 0,
        "temperature" => 0,
        "humidity" => 0,
        "rain_collected" => false,
        "relay_status" => "OFF",
        "mode" => "AUTO",
        "timestamp" => null
    ]);
}
$conn->close();
?>
