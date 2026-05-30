from flask import Flask, request, jsonify
from flask_cors import CORS

from models import (
    DEVICE,
    colon_model,
    breast_model,
    get_models_status
)


app = Flask(__name__)
CORS(app)


def get_image_bytes_from_request():
    """
    Supports:
    1) multipart/form-data with key = file
    2) raw binary body
    """

    if "file" in request.files:
        return request.files["file"].read()

    if request.data:
        return request.data

    return None


@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "success": True,
        "message": "AI Models Backend is running.",
        "device": str(DEVICE),
        "available_endpoints": [
            "/models/status",
            "/predict-pathology",
            "/predict-breast"
        ]
    })


@app.route("/models/status", methods=["GET"])
def models_status():
    return jsonify({
        "success": True,
        **get_models_status()
    })


@app.route("/predict-pathology", methods=["POST"])
def predict_pathology():
    try:
        image_bytes = get_image_bytes_from_request()

        if image_bytes is None:
            return jsonify({
                "success": False,
                "message": "No image file uploaded. Use form-data with key 'file'."
            }), 400

        result = colon_model.predict(image_bytes)

        status_code = 200 if result.get("success") else 503
        return jsonify(result), status_code

    except Exception as e:
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500


@app.route("/predict-breast", methods=["POST"])
def predict_breast():
    try:
        image_bytes = get_image_bytes_from_request()

        if image_bytes is None:
            return jsonify({
                "success": False,
                "message": "No image file uploaded. Use form-data with key 'file'."
            }), 400

        result = breast_model.predict(image_bytes)

        status_code = 200 if result.get("success") else 503
        return jsonify(result), status_code

    except Exception as e:
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5001,
        debug=True
    )