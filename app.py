from flask import Flask, render_template, request, redirect, session, jsonify
import pymysql
from db import get_conn
from datetime import date

app = Flask(__name__)
app.secret_key = 'coffee_secret'

# ==================== 注册 ====================
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        prefs = request.form.getlist('preferences')
        if len(prefs) < 3:
            return render_template('register.html', error='请至少选择3个偏好')
        conn = get_conn()
        try:
            with conn.cursor() as cur:
                # 检查用户名是否已存在
                cur.execute("SELECT user_id FROM User WHERE username=%s", (username,))
                if cur.fetchone():
                    return render_template('register.html', error='该用户名已被注册，请换一个')
                
                cur.execute("INSERT INTO User(username,password) VALUES(%s,%s)",
                            (username, password))
                user_id = cur.lastrowid
                for p in prefs:
                    cur.execute("INSERT INTO UserPreference(user_id,coffee_type) VALUES(%s,%s)",
                                (user_id, p))
            conn.commit()
        finally:
            conn.close()
        return redirect('/login')
    return render_template('register.html')

# ==================== 登录 ====================
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        conn = get_conn()
        try:
            with conn.cursor() as cur:
                # 先查用户名是否存在
                cur.execute("SELECT user_id, password FROM User WHERE username=%s", (username,))
                row = cur.fetchone()
        finally:
            conn.close()
        
        if not row:
            return render_template('index.html', error='该用户名尚未注册，请先注册')
        if row[1] != password:
            return render_template('index.html', error='密码错误，请重试')
        
        session['user_id'] = row[0]
        session['username'] = username
        return redirect('/dashboard')
    return render_template('index.html')

# ==================== 用户主页+推荐 ====================
@app.route('/dashboard')
def dashboard():
    if 'user_id' not in session:
        return redirect('/login')
    user_id = session['user_id']
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            # 获取用户偏好
            cur.execute("SELECT coffee_type FROM UserPreference WHERE user_id=%s", (user_id,))
            prefs = [r[0] for r in cur.fetchall()]

            # 根据偏好推荐（基于用户画像+历史）
            if prefs:
                fmt = ','.join(['%s'] * len(prefs))
                cur.execute(f"""
                    SELECT c.coffee_id, c.name, c.type, c.popularity
                    FROM Coffee c
                    WHERE c.type IN ({fmt})
                    AND c.coffee_id NOT IN (
                        SELECT coffee_id FROM DrinkRecord WHERE user_id=%s
                    )
                    ORDER BY c.popularity DESC LIMIT 5
                """, (*prefs, user_id))
            else:
                # 新用户推荐5款热门
                cur.execute("SELECT coffee_id, name, type, popularity FROM Coffee ORDER BY popularity DESC LIMIT 5")
            recommendations = cur.fetchall()

            # 历史记录
            cur.execute("""
                SELECT c.name, dr.drink_date, dr.quantity, dr.taste_score
                FROM DrinkRecord dr
                JOIN Coffee c ON dr.coffee_id = c.coffee_id
                WHERE dr.user_id = %s ORDER BY dr.drink_date DESC LIMIT 10
            """, (user_id,))
            history = cur.fetchall()
    finally:
        conn.close()
    return render_template('dashboard.html',
                           username=session['username'],
                           recommendations=recommendations,
                           history=history)

# ==================== 记录喝咖啡（触发器+存储过程） ====================
@app.route('/drink', methods=['GET', 'POST'])
def drink():
    if 'user_id' not in session:
        return redirect('/login')
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT coffee_id, name, shop FROM Coffee ORDER BY shop, name")
            all_coffees = cur.fetchall()
            from collections import defaultdict
            shops = defaultdict(list)
            for cid, cname, shop in all_coffees:
                shops[shop].append((cid, cname))

        if request.method == 'POST':
            coffee_id = int(request.form['coffee_id'])
            quantity = int(request.form['quantity'])
            score = int(request.form['taste_score'])
            cup_size = request.form.get('cup_size', '大杯')
            temperature = request.form.get('temperature', '正常冰')
            caffeine = request.form.get('caffeine') or None
            price = request.form.get('price') or None
            if caffeine:
                caffeine = int(caffeine)
            if price:
                price = float(price)
            with conn.cursor() as cur:
                conn.begin()
                cur.execute("""
                    INSERT INTO DrinkRecord(user_id, coffee_id, drink_date, quantity, cup_size, temperature, caffeine, price, taste_score)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (session['user_id'], coffee_id, date.today(), quantity, cup_size, temperature, caffeine, price, score))
                conn.commit()
            return redirect('/dashboard')
    except Exception as e:
        return render_template('drink.html', shops=dict(shops), error=str(e))
    finally:
        conn.close()
    return render_template('drink.html', shops=dict(shops))

# ==================== 删除账户（事务清理） ====================
@app.route('/delete_account', methods=['POST'])
def delete_account():
    if 'user_id' not in session:
        return redirect('/login')
    user_id = session['user_id']
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            conn.begin()
            # 事务：先删记录，再重算热度，最后删用户
            cur.execute("SELECT coffee_id, taste_score FROM DrinkRecord WHERE user_id=%s", (user_id,))
            records = cur.fetchall()
            for coffee_id, score in records:
                cur.execute("UPDATE Coffee SET popularity = popularity - %s WHERE coffee_id=%s",
                            (score, coffee_id))
            cur.execute("DELETE FROM DrinkRecord WHERE user_id=%s", (user_id,))
            cur.execute("DELETE FROM UserPreference WHERE user_id=%s", (user_id,))
            cur.execute("DELETE FROM User WHERE user_id=%s", (user_id,))
        conn.commit()
    except:
        conn.rollback()
        raise
    finally:
        conn.close()
    session.clear()
    return redirect('/login')

# ==================== 榜单（视图查询） ====================
@app.route('/ranking')
def ranking():
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT name, shop, type, popularity, drink_count, avg_score FROM v_coffee_ranking LIMIT 10")
            rows = cur.fetchall()
    finally:
        conn.close()
    return render_template('ranking.html', rows=rows)

@app.route('/')
def index():
    return redirect('/login')

@app.route('/logout')
def logout():
    session.clear()
    return redirect('/login')

if __name__ == '__main__':
    app.run(debug=True)