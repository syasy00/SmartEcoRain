<?php
require_once("dbconnect.php");

// Handle POST for updating status/mode
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents('php://input'), true);
    $status = (isset($data['status']) && $data['status'] == 'ON') ? 'ON' : 'OFF';
    $mode = (isset($data['mode']) && $data['mode'] == 'MANUAL') ? 'MANUAL' : 'AUTO';
    $conn->query("UPDATE pump_control SET status='$status', mode='$mode' WHERE id=1");
    echo json_encode(['status' => $status, 'mode' => $mode]);
    exit;
}

// Handle GET to fetch current status/mode
$result = $conn->query("SELECT status, mode FROM pump_control WHERE id=1");
$row = $result->fetch_assoc();
echo json_encode(['status' => $row['status'], 'mode' => $row['mode']]);
$conn->close();
?>
