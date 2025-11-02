from flask import Flask, jsonify, request
import os

# Global variable to simulate in-memory storage
WORKOUTS = [] 
APP_VERSION = "1.0" 

# This is the 'app' instance Gunicorn needs
app = Flask(__name__) 

def add_workout_logic(workout, duration_str):
    """Handles the core logic for adding a workout."""
    if not workout or not duration_str:
        return {"status": "error", "message": "Please enter both workout and duration."}

    try:
        duration = int(duration_str)
        if duration <= 0:
            return {"status": "error", "message": "Duration must be a positive number."}
        WORKOUTS.append({"workout": workout, "duration": duration})
        return {"status": "success", "message": f"'{workout}' added successfully!"}
    except ValueError:
        return {"status": "error", "message": "Duration must be a number."}

# --- FLASK ENDPOINTS ---

@app.route("/", methods=["GET"])
def home():
    """Welcome message and version check."""
    return f"Welcome to ACEest Fitness & Gym! Application Version: {APP_VERSION}"

@app.route("/health", methods=["GET"])
def health_check():
    """Liveness and Readiness Probe endpoint for Kubernetes."""
    return jsonify({"status": "UP", "version": APP_VERSION}), 200

@app.route("/api/workouts", methods=["POST"])
def add_workout():
    """API endpoint to add a new workout."""
    data = request.get_json()
    workout = data.get("workout", "")
    duration_str = str(data.get("duration", ""))
    result = add_workout_logic(workout, duration_str)

    if result["status"] == "error":
        return jsonify(result), 400
    
    return jsonify(result), 201

@app.route("/api/workouts", methods=["GET"])
def get_workouts():
    """API endpoint to view all logged workouts."""
    summary = {
        "total_workouts": len(WORKOUTS),
        "workouts": WORKOUTS
    }
    return jsonify(summary)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(debug=True, host='0.0.0.0', port=port)