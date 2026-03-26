"""Dummy token generator extension for dserver development.
Accepts any username/password and issues a valid JWT.
DO NOT use in production.
"""
__version__ = "0.1.0"

import datetime
import logging

import jwt
from flask import current_app, jsonify, request
from flask_smorest import Blueprint

logger = logging.getLogger(__name__)

bp = Blueprint("dummy_auth", __name__, url_prefix="/auth")


@bp.route("/token", methods=["POST"])
def create_token():
    data = request.get_json(silent=True) or {}
    username = data.get("username") or request.form.get("username")
    if not username:
        return jsonify({"error": "Missing api_key or username"}), 401

    import os
    private_key_file = current_app.config.get("JWT_PRIVATE_KEY_FILE") or os.environ.get("JWT_PRIVATE_KEY_FILE")
    algorithm = current_app.config.get("JWT_ALGORITHM") or os.environ.get("JWT_ALGORITHM", "RS256")
    with open(private_key_file, "r") as f:
        private_key = f.read()

    payload = {
        "sub": username,
        "identity": username,
        "iat": datetime.datetime.utcnow(),
        "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=24),
    }
    token = jwt.encode(payload, private_key, algorithm=algorithm)
    return jsonify({"token": token})


@bp.route("/token", methods=["GET"])
def get_token_info():
    return jsonify({"msg": 'POST /auth/token with {"username": "..."}'}), 200


@bp.route("/info", methods=["GET"])
def auth_info():
    return jsonify({"configured": True, "provider": "dummy", "login_url": None})


class DummyTokenGeneratorPlugin:
    """dservercore ExtensionABC-compatible dummy token generator."""

    def __init__(self, app=None):
        if app is not None:
            self.init_app(app)

    def init_app(self, app, *args, **kwargs):
        logger.warning("DummyTokenGeneratorPlugin loaded — dev only, not for production!")

    def get_blueprint(self):
        return bp

    def get_config(self):
        return {}

    def get_config_secrets_to_obfuscate(self):
        return []
