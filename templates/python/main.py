import os

from flask import Flask

app = Flask(__name__)


@app.get("/")
def index():
    return "<h1>__SLUG__</h1><p>Edit <code>projects/__SLUG__/main.py</code> to get started.</p>"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)), debug=True)
