<?php
include 'dbconnect.php';

$email = $_POST['email'] ?? '';
$password = $_POST['password'] ?? '';

$query = $conn->prepare("SELECT * FROM users WHERE email = ?");
$query->bind_param("s", $email);
$query->execute();
$result = $query->get_result();

if ($row = $result->fetch_assoc()) {
    if (password_verify($password, $row['password'])) {
        echo json_encode(["status" => "success", "username" => $row['username']]);
    } else {
        echo json_encode(["status" => "fail", "message" => "Incorrect password"]);
    }
} else {
    echo json_encode(["status" => "fail", "message" => "User not found"]);
}
?>
