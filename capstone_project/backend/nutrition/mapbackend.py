```
파이썬 지도 백엔드
```
import os
from flask import Flask, jsonify, request
from flask_cors import CORS
import requests
from dotenv import load_dotenv

# .env 파일에서 환경 변수 로드
load_dotenv()

app = Flask(__name__)
# Flutter 웹 앱(localhost)에서의 요청을 허용합니다.
CORS(app)

# Google Maps API 키를 환경 변수에서 가져옵니다.
# .env 파일에 GOOGLE_API_KEY="YOUR_KEY"와 같이 저장하거나
# 터미널에서 직접 설정해야 합니다.
GOOGLE_API_KEY = os.getenv('GOOGLE_API_KEY')

if not GOOGLE_API_KEY:
    print("경고: GOOGLE_API_KEY가 설정되지 않았습니다. .env 파일을 확인하세요.")

# 한림대학교 주요 건물 좌표 데이터 (기획안에 맞춰 DB 또는 파일로 분리 가능)
hallym_buildings = [
    {'id': 'main_gate', 'name': '정문', 'lat': 37.8824, 'lng': 127.7360},
    {'id': 'main_building', 'name': '대학본부', 'lat': 37.8839, 'lng': 127.7378},
    {'id': 'student_union', 'name': '학생회관', 'lat': 37.8845, 'lng': 127.7365},
    {'id': 'library', 'name': '도서관', 'lat': 37.8853, 'lng': 127.7383},
    {'id': 'international', 'name': '국제교육관', 'lat': 37.8829, 'lng': 127.7401},
    {'id': 'engineering_1', 'name': '공학관 1', 'lat': 37.8860, 'lng': 127.7415},
    {'id': 'social_science', 'name': '사회과학관', 'lat': 37.8848, 'lng': 127.7408},
]

@app.route('/buildings', methods=['GET'])
def get_buildings():
    """건물 목록을 JSON 형태로 반환합니다."""
    return jsonify(hallym_buildings)

@app.route('/directions', methods=['GET'])
def get_directions():
    """출발지와 목적지 간의 도보 경로를 Google API에서 받아와 반환합니다."""
    origin_lat = request.args.get('originLat')
    origin_lng = request.args.get('originLng')
    dest_lat = request.args.get('destLat')
    dest_lng = request.args.get('destLng')

    if not all([origin_lat, origin_lng, dest_lat, dest_lng]):
        return jsonify({'error': '출발지와 목적지 좌표가 필요합니다.'}), 400

    if not GOOGLE_API_KEY:
        return jsonify({'error': '서버에 Google API 키가 설정되지 않았습니다.'}), 500

    url = (
        f"https://maps.googleapis.com/maps/api/directions/json?"
        f"origin={origin_lat},{origin_lng}&destination={dest_lat},{dest_lng}"
        f"&mode=walking&language=ko&key={GOOGLE_API_KEY}"
    )

    try:
        response = requests.get(url)
        data = response.json()

        if data.get('status') == 'OK':
            route = data['routes'][0]
            leg = route['legs'][0]

            # 프론트엔드에 필요한 정보만 가공
            simplified_route = {
                'polyline': route['overview_polyline']['points'],
                'bounds': route['bounds'],
                'steps': [{
                    'html_instructions': step['html_instructions'],
                    'distance': step['distance']['text'],
                    'duration': step['duration']['text'],
                } for step in leg['steps']],
                'totalDistance': leg['distance']['text'],
                'totalDuration': leg['duration']['text'],
            }
            return jsonify(simplified_route)
        else:
            return jsonify({'error': '경로를 찾을 수 없습니다.', 'details': data.get('status')}), 500

    except requests.RequestException as e:
        print(f"Google Directions API 요청 중 오류 발생: {e}")
        return jsonify({'error': 'Google Directions API 요청 중 오류 발생'}), 500
    except Exception as e:
        print(f"경로 데이터 처리 중 오류 발생: {e}")
        return jsonify({'error': '서버 내부 오류 발생'}), 500

# Python 스크립트가 직접 실행될 때 Flask 서버를 시작합니다.
if __name__ == '__main__':
    # 기본 포트 5000으로 실행됩니다.
    app.run(debug=True)
