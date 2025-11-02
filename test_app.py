import pytest
import json
from ACEest_Fitness import app

@pytest.fixture
def client():
    """Create a test client for the Flask app."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health_check_endpoint(client):
    """Test the /health endpoint for Kubernetes probes."""
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == "UP"