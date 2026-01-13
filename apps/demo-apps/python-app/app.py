from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, generate_latest, REGISTRY
import time
import os

app = Flask(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status_code']
)

    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

# -- Business Metrics --
from prometheus_client import Gauge
import random
import threading

INVENTORY_STOCK = Gauge(
    'inventory_stock_count',
    'Current stock level of product',
    ['product_id']
)

CHECKOUT_TIME = Histogram(
    'checkout_processing_seconds',
    'Time taken to process checkout',
    buckets=(0.1, 0.5, 1.0, 2.0, 5.0)
)

# Background simulation
def simulate_metrics():
    # Init stocks
    stocks = {1: 50, 2: 200, 3: 15, 4: 5}
    while True:
        time.sleep(5)
        # Update stock
        for pid, count in stocks.items():
            # Randomly decrease stock, restock if low
            change = random.randint(-2, 1)
            stocks[pid] = max(0, stocks[pid] + change)
            if stocks[pid] < 5:
                 if random.random() > 0.8: stocks[pid] += 20 # Restock
            
            INVENTORY_STOCK.labels(product_id=pid).set(stocks[pid])
        
        # Simulate checkout latency
        if random.random() > 0.7:
             CHECKOUT_TIME.observe(random.uniform(0.1, 1.5))

threading.Thread(target=simulate_metrics, daemon=True).start()

# Middleware to track metrics
@app.before_request
def before_request():
    request.start_time = time.time()

@app.after_request
def after_request(response):
    if hasattr(request, 'start_time'):
        duration = time.time() - request.start_time
        REQUEST_DURATION.labels(
            method=request.method,
            endpoint=request.endpoint or 'unknown'
        ).observe(duration)
        
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.endpoint or 'unknown',
            status_code=response.status_code
        ).inc()
    
    return response

# Routes
@app.route('/api', methods=['GET'])
def index():
    return jsonify({
        'message': 'Welcome to CloudLab Python API!',
        'version': '1.0.0',
        'framework': 'Flask',
        'endpoints': {
            'health': '/api/health',
            'metrics': '/metrics',
            'info': '/api/info',
            'products': '/api/products'
        }
    })

@app.route('/api/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'healthy',
        'timestamp': time.time()
    }), 200

@app.route('/api/info', methods=['GET'])
def info():
    return jsonify({
        'app': 'CloudLab Python API',
        'version': '1.0.0',
        'python_version': os.sys.version,
        'framework': 'Flask'
    })

@app.route('/api/products', methods=['GET'])
def products():
    products_data = [
        {'id': 1, 'name': 'Laptop', 'price': 1200, 'category': 'Electronics'},
        {'id': 2, 'name': 'Mouse', 'price': 25, 'category': 'Electronics'},
        {'id': 3, 'name': 'Keyboard', 'price': 75, 'category': 'Electronics'},
        {'id': 4, 'name': 'Monitor', 'price': 300, 'category': 'Electronics'}
    ]
    
    return jsonify({
        'count': len(products_data),
        'data': products_data
    })

@app.route('/api/products/<int:product_id>', methods=['GET'])
def get_product(product_id):
    products_data = [
        {'id': 1, 'name': 'Laptop', 'price': 1200, 'category': 'Electronics'},
        {'id': 2, 'name': 'Mouse', 'price': 25, 'category': 'Electronics'},
        {'id': 3, 'name': 'Keyboard', 'price': 75, 'category': 'Electronics'},
        {'id': 4, 'name': 'Monitor', 'price': 300, 'category': 'Electronics'}
    ]
    
    product = next((p for p in products_data if p['id'] == product_id), None)
    
    if product:
        return jsonify(product)
    else:
        return jsonify({'error': 'Product not found'}), 404

# Metrics endpoint for Prometheus
@app.route('/metrics', methods=['GET'])
def metrics():
    return generate_latest(REGISTRY), 200, {'Content-Type': 'text/plain; charset=utf-8'}

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not Found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal Server Error'}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
