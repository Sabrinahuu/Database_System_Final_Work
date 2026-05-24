# -*- coding: utf-8 -*-
import calendar
from flask import Flask, render_template, request, redirect, session, jsonify
from db import get_conn
from datetime import date
from collections import defaultdict

app = Flask(__name__)
app.secret_key = 'coffee_secret'


def split_tag_names(preferences):
    tag_names = []

    for pref in preferences:
        if not pref:
            continue

        pref = pref.replace('，', ',')
        parts = pref.split(',')

        for tag in parts:
            tag = tag.strip()
            if tag and tag not in tag_names:
                tag_names.append(tag)

    return tag_names


def load_shops_and_tags(cur):
    cur.execute("""
        SELECT coffee_id, name, shop
        FROM Coffee
        ORDER BY shop, name
    """)
    all_coffees = cur.fetchall()

    shops = defaultdict(list)
    for coffee_id, name, shop in all_coffees:
        shops[shop].append((coffee_id, name))

    coffee_tags = {}

    try:
        cur.execute("""
            SELECT coffee_id, flavor_tags
            FROM v_coffee_tags
        """)
        for coffee_id, flavor_tags in cur.fetchall():
            coffee_tags[coffee_id] = flavor_tags or ''
    except Exception:
        coffee_tags = {}

    return dict(shops), coffee_tags


def get_recommendations(cur, user_id):
    try:
        cur.callproc('sp_recommend_coffee', (user_id,))
        rows = cur.fetchall()

        while cur.nextset():
            pass

        return rows

    except Exception as e:
        print("调用 sp_recommend_coffee 失败，使用备用推荐 SQL：", e)

        try:
            cur.execute("""
                SELECT
                    c.coffee_id,
                    c.name,
                    c.shop,
                    c.type,
                    IFNULL(v.flavor_tags, '') AS tags,
                    ROUND(
                        COALESCE(SUM(up.weight * cft.weight), 0)
                        + COALESCE(c.popularity, 0) * 0.05,
                        2
                    ) AS recommend_score
                FROM UserPreference up
                JOIN CoffeeFlavorTag cft 
                    ON up.tag_id = cft.tag_id
                JOIN Coffee c 
                    ON cft.coffee_id = c.coffee_id
                LEFT JOIN v_coffee_tags v 
                    ON c.coffee_id = v.coffee_id
                WHERE up.user_id = %s
                  AND c.coffee_id NOT IN (
                      SELECT coffee_id
                      FROM DrinkRecord
                      WHERE user_id = %s
                  )
                GROUP BY 
                    c.coffee_id, 
                    c.name, 
                    c.shop, 
                    c.type, 
                    v.flavor_tags, 
                    c.popularity
                ORDER BY recommend_score DESC
                LIMIT 5
            """, (user_id, user_id))

            return cur.fetchall()

        except Exception as e:
            print("备用推荐 SQL 失败，使用热门咖啡推荐：", e)

            cur.execute("""
                SELECT
                    c.coffee_id,
                    c.name,
                    c.shop,
                    c.type,
                    IFNULL(v.flavor_tags, '') AS tags,
                    COALESCE(c.popularity, 0) AS recommend_score
                FROM Coffee c
                LEFT JOIN v_coffee_tags v 
                    ON c.coffee_id = v.coffee_id
                ORDER BY c.popularity DESC
                LIMIT 5
            """)

            return cur.fetchall()


@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form['username'].strip()
        password = request.form['password']
        prefs = request.form.getlist('preferences')

        tag_names = split_tag_names(prefs)

        if len(prefs) < 1:
            return render_template('register.html', error='请至少选择1个偏好')

        if len(prefs) > 3:
            return render_template('register.html', error='最多选择3个偏好')

        if not tag_names:
            return render_template('register.html', error='偏好数据为空，请重新选择')

        conn = get_conn()

        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT user_id
                    FROM User
                    WHERE username = %s
                """, (username,))

                if cur.fetchone():
                    return render_template('register.html', error='该用户名已被注册，请换一个')

                fmt = ','.join(['%s'] * len(tag_names))
                cur.execute(f"""
                    SELECT tag_id, tag_name
                    FROM FlavorTag
                    WHERE tag_name IN ({fmt})
                """, tag_names)

                tag_rows = cur.fetchall()

                if not tag_rows:
                    return render_template('register.html', error='没有找到对应的口味标签，请检查数据库初始化数据')

                conn.begin()

                cur.execute("""
                    INSERT INTO User(username, password)
                    VALUES (%s, %s)
                """, (username, password))

                user_id = cur.lastrowid

                for tag_id, tag_name in tag_rows:
                    cur.execute("""
                        INSERT INTO UserPreference(user_id, tag_id, weight, source)
                        VALUES (%s, %s, %s, %s)
                    """, (user_id, tag_id, 1.00, 'register'))

                conn.commit()

        except Exception as e:
            conn.rollback()
            return render_template('register.html', error=str(e))

        finally:
            conn.close()

        return redirect('/login')

    return render_template('register.html')


@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username'].strip()
        password = request.form['password']

        conn = get_conn()

        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT user_id, password
                    FROM User
                    WHERE username = %s
                """, (username,))
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


@app.route('/dashboard')
def dashboard():
    if 'user_id' not in session:
        return redirect('/login')

    return redirect('/recommendations')


@app.route('/recommendations')
def recommendations():
    if 'user_id' not in session:
        return redirect('/login')

    user_id = session['user_id']
    conn = get_conn()

    try:
        with conn.cursor() as cur:
            recommendations = get_recommendations(cur, user_id)

    finally:
        conn.close()

    return render_template(
        'recommendations.html',
        username=session['username'],
        recommendations=recommendations
    )


@app.route('/history')
def history():
    if 'user_id' not in session:
        return redirect('/login')

    user_id = session['user_id']

    today = date.today()
    year = int(request.args.get('year', today.year))
    month = int(request.args.get('month', today.month))

    first_day = date(year, month, 1)
    last_day_num = calendar.monthrange(year, month)[1]
    last_day = date(year, month, last_day_num)

    if month == 1:
        prev_year, prev_month = year - 1, 12
    else:
        prev_year, prev_month = year, month - 1

    if month == 12:
        next_year, next_month = year + 1, 1
    else:
        next_year, next_month = year, month + 1

    conn = get_conn()

    try:
        with conn.cursor() as cur:
            cur.execute("""
    SELECT
        c.name,
        c.shop,
        dr.drink_date,
        dr.quantity,
        dr.cup_size,
        dr.temperature,
        dr.caffeine,
        dr.price,
        dr.taste_score
    FROM DrinkRecord dr
    JOIN Coffee c ON dr.coffee_id = c.coffee_id
    WHERE dr.user_id = %s
      AND dr.drink_date BETWEEN %s AND %s
    ORDER BY dr.drink_date DESC
""", (user_id, first_day, last_day))

            rows = cur.fetchall()

    finally:
        conn.close()

    drink_days = {}
    history = []

    for name, shop, drink_date, quantity, cup_size, temperature, caffeine, price, taste_score in rows:
        day = drink_date.day
        drink_days[day] = drink_days.get(day, 0) + quantity

        history.append((
        name,
        shop,
        f'{drink_date.month}月{drink_date.day}日',
        quantity,
        cup_size,
        temperature,
        caffeine,
        price,
        taste_score
    ))

    cal = calendar.Calendar(firstweekday=6)
    month_calendar = cal.monthdayscalendar(year, month)

    return render_template(
        'history.html',
        username=session['username'],
        history=history,
        month_calendar=month_calendar,
        drink_days=drink_days,
        year=year,
        month=month,
        today=today,
        prev_year=prev_year,
        prev_month=prev_month,
        next_year=next_year,
        next_month=next_month
    )


@app.route('/drink', methods=['GET', 'POST'])
def drink():
    if 'user_id' not in session:
        return redirect('/login')

    conn = get_conn()
    shops = {}
    coffee_tags = {}

    try:
        with conn.cursor() as cur:
            shops, coffee_tags = load_shops_and_tags(cur)

        if request.method == 'POST':
            shop_select = request.form.get('shop_select')
            coffee_select = request.form.get('coffee_id', '').strip()
            custom_shop = request.form.get('custom_shop_name', '').strip() \
                          if shop_select == '__custom__' else shop_select

            custom_coffee = request.form.get('custom_coffee_name', '').strip() \
                            if coffee_select == '__custom__' else None

            if custom_coffee:
                with conn.cursor() as cur2:
                    cur2.execute(
                        "SELECT coffee_id FROM Coffee WHERE name=%s AND shop=%s",
                        (custom_coffee, custom_shop)
                    )
                    row = cur2.fetchone()
                    if row:
                        coffee_id = row[0]
                    else:
                        cur2.execute(
                            "INSERT INTO Coffee(name, shop,type, popularity) VALUES(%s, %s, %s, %s)",
                            (custom_coffee, custom_shop,'Custom', 0)
                        )
                        coffee_id = cur2.lastrowid
            else:
                coffee_id = int(request.form['coffee_id'])
            quantity = int(request.form['quantity'])
            score = int(request.form['taste_score'])
            cup_size = request.form.get('cup_size', '大杯')
            temperature = request.form.get('temperature', '正常冰')

            drink_date = request.form.get('drink_date') or date.today()

            caffeine = request.form.get('caffeine') or None
            price = request.form.get('price') or None

            if caffeine is not None:
                caffeine = int(caffeine)

            if price is not None:
                price = float(price)

            try:
                with conn.cursor() as cur:
                    conn.begin()

                    cur.callproc(
                        'sp_add_drink_record',
                        (
                            session['user_id'],
                            coffee_id,
                            drink_date,
                            quantity,
                            cup_size,
                            temperature,
                            caffeine,
                            price,
                            score
                        )
                    )

                    while cur.nextset():
                        pass

                    conn.commit()

            except Exception:
                conn.rollback()

                with conn.cursor() as cur:
                    conn.begin()

                    cur.execute("""
                        INSERT INTO DrinkRecord(
                            user_id,
                            coffee_id,
                            drink_date,
                            quantity,
                            cup_size,
                            temperature,
                            caffeine,
                            price,
                            taste_score
                        )
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        session['user_id'],
                        coffee_id,
                        drink_date,
                        quantity,
                        cup_size,
                        temperature,
                        caffeine,
                        price,
                        score
                    ))
                    cur.execute("""
                        UPDATE Coffee
                        SET popularity = COALESCE(popularity, 0) + %s
                        WHERE coffee_id = %s
""", (quantity, coffee_id))
                    conn.commit()

            return redirect('/dashboard')

    except Exception as e:
        return render_template(
            'drink.html',
            shops=shops,
            coffee_tags=coffee_tags,
            error=str(e)
        )

    finally:
        conn.close()

    return render_template(
        'drink.html',
        shops=shops,
        coffee_tags=coffee_tags
    )


@app.route('/delete_account', methods=['POST'])
def delete_account():
    if 'user_id' not in session:
        return redirect('/login')

    user_id = session['user_id']
    conn = get_conn()

    try:
        with conn.cursor() as cur:
            conn.begin()

            cur.execute("""
                DELETE FROM DrinkRecord
                WHERE user_id = %s
            """, (user_id,))

            cur.execute("""
                DELETE FROM UserPreference
                WHERE user_id = %s
            """, (user_id,))

            cur.execute("""
                DELETE FROM User
                WHERE user_id = %s
            """, (user_id,))

            conn.commit()

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()

    session.clear()
    return redirect('/login')


@app.route('/ranking')
def ranking():
    conn = get_conn()

    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    c.name,
                    c.shop,
                    COALESCE(c.type, 'Custom') AS type,
                    COALESCE(c.popularity, 0) AS popularity,
                    COALESCE(SUM(dr.quantity), 0) AS drink_count,
                    ROUND(AVG(dr.taste_score), 1) AS avg_score,
                    IFNULL(v.flavor_tags, '') AS tags
                FROM Coffee c
                JOIN DrinkRecord dr
                    ON c.coffee_id = dr.coffee_id
                LEFT JOIN v_coffee_tags v
                    ON c.coffee_id = v.coffee_id
                GROUP BY
                    c.coffee_id,
                    c.name,
                    c.shop,
                    c.type,
                    c.popularity,
                    v.flavor_tags
                ORDER BY
                    drink_count DESC,
                    avg_score DESC,
                    popularity DESC
                LIMIT 10
            """)

            rows = cur.fetchall()

    finally:
        conn.close()

    return render_template('ranking.html', rows=rows)


@app.route('/api/flavor-tags')
def api_flavor_tags():
    conn = get_conn()

    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT tag_id, tag_name, tag_group
                FROM FlavorTag
                ORDER BY tag_group, tag_name
            """)

            rows = cur.fetchall()

    finally:
        conn.close()

    data = [
        {
            'tag_id': row[0],
            'tag_name': row[1],
            'tag_group': row[2]
        }
        for row in rows
    ]

    return jsonify(data)


@app.route('/')
def index():
    return redirect('/login')


@app.route('/logout')
def logout():
    session.clear()
    return redirect('/login')


if __name__ == '__main__':
    app.run(debug=True)