import os  # BẮT BUỘC PHẢI CÓ
from flask import Flask, render_template, request, jsonify
import mysql.connector

app = Flask(__name__)

# MySQL Config - Lấy thông tin từ biến môi trường

db = mysql.connector.connect(
    host=os.getenv("DB_HOST"),
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    database=os.getenv("DB_NAME"),
    ssl_ca='/app/global-bundle.pem',
    ssl_verify_identity=True
)

cursor = db.cursor()

# Tạo bảng nếu chưa tồn tại
cursor.execute("""
CREATE TABLE IF NOT EXISTS scores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    player VARCHAR(50),
    score INT
)
""")
db.commit()
@app.route("/health")
def health():
    return "OK", 200
@app.route("/")
def home():
    return render_template("index.html")

@app.route("/save-score", methods=["POST"])
def save_score():
    data = request.json
    player = data["player"]
    score = data["score"]

    sql = "INSERT INTO scores (player, score) VALUES (%s, %s)"
    val = (player, score)

    cursor.execute(sql, val)
    db.commit()
    return jsonify({"message": "Score Saved"})

@app.route("/leaderboard")
def leaderboard():
    cursor.execute("SELECT player, score FROM scores ORDER BY score DESC LIMIT 10")
    results = cursor.fetchall()
    leaderboard_data = [{"player": row[0], "score": row[1]} for row in results]
    return jsonify(leaderboard_data)

if __name__ == "__main__":
    # Host='0.0.0.0' để Docker container có thể lắng nghe từ bên ngoài
    app.run(host='0.0.0.0', port=5000)
