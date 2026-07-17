import os

import traceback  # <--- THÊM DÒNG NÀY VÀO ĐẦU FILE
import logging
from flask import Flask, render_template, request, jsonify
import mysql.connector
import sys
app = Flask(__name__, template_folder='templates')

# Cấu hình log để nhìn thấy mọi thứ
app.logger.addHandler(logging.StreamHandler(sys.stdout))
app.logger.setLevel(logging.ERROR)

def get_db():
    try:
        return mysql.connector.connect(
            host=os.getenv("DB_HOST"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
            database=os.getenv("DB_NAME"),
            ssl_disabled=True
        )
    except Exception as e:
        app.logger.error(f"Database Connection Error: {str(e)}")
        raise e

@app.route("/")
def home():
    try:
        return render_template("index.html")
    except Exception:
        # Dòng này sẽ in toàn bộ traceback ra log để bạn xem
        app.logger.error(f"Home route error: {traceback.format_exc()}")
        return "Internal Server Error", 500

@app.route("/health")
def health():
    return "OK", 200

@app.route("/save-score", methods=["POST"])
def save_score():
    data = request.json
    conn = get_db() # Mở kết nối
    cursor = conn.cursor()
    try:
        sql = "INSERT INTO scores (player, score) VALUES (%s, %s)"
        cursor.execute(sql, (data["player"], data["score"]))
        conn.commit()
    finally:
        cursor.close()
        conn.close() # Đóng kết nối để tránh lỗi kết nối bị treo
    return jsonify({"message": "Score Saved"})

@app.route("/leaderboard")
def leaderboard():
    conn = get_db() # Mở kết nối
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT player, score FROM scores ORDER BY score DESC LIMIT 10")
        results = cursor.fetchall()
        leaderboard_data = [{"player": row[0], "score": row[1]} for row in results]
    finally:
        cursor.close()
        conn.close() # Đóng kết nối
    return jsonify(leaderboard_data)

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)
