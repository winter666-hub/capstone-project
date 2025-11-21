#파이썬 지도 백엔드

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
hallym_buildings = [{
    {'id': 'main_gate', 'name': '정문', 'lat': 37.883970, 'lng': 127.737828},
    {'id': 'CLC', 'name': 'Campus Life Center', 'lat': 37.886730, 'lng': 127.740115},
    {'id': 'library', 'name': '일송기념도서관', 'lat': 37.884777, 'lng': 127.737378},
    {'id': 'international', 'name': '국제관', 'lat': 37.886737, 'lng': 127.740976},
    {'id': 'engineering', 'name': '공학관', 'lat': 37.886341, 'lng': 127.735815},
    {'id': 'social_science_first', 'name': '사회경영1관', 'lat': 37.888278, 'lng': 127.748232},
    {'id': '', 'name':'대학본부 * 인문1관', 'lat': 37.886552, 'lng': 127.737988},
    {'id': '', 'name':'인문 2관', 'lat': 37.886359, 'lng': 127.737371},
    {'id': '', 'name':'산학협력관', 'lat': 37.887360, 'lng': 127.738165},
    {'id': '', 'name':'의료*바이오융합연구원', 'lat': 37.885969, 'lng': 127.737688},
    {'id': '', 'name':'도헌글로벌스쿨', 'lat': 37.884582, 'lng':127.736506},
    {'id': '', 'name':'사색의 길', 'lat': 37.885446, 'lng':127.737161},
    {'id': '', 'name':'생명의 숲', 'lat': 37.885453, 'lng':127.736249},
    {'id': '','name':'일송정원', 'lat': 37.886007, 'lng':127.736013},
    {'id': '', 'name':'의학관', 'lat': 37.885974, 'lng':127.737267},
    {'id': '', 'name':'대학본부별관', 'lat': 37.886644, 'lng':127.738688},
    {'id': '', 'name':'창업보육센터', 'lat': 37.885026, 'lng':127.735725},
    {'id': '', 'name':'커뮤니티교육원', 'lat': 37.884385, 'lng':127.738757},
    {'id': 'social_science_second', 'name':'사회*경영2관', 'lat': 37.887804, 'lng':127.738344},
    {'id': '', 'name':'자연과학관', 'lat': 37.885827, 'lng': 127.736789},
    {'id': '', 'name':'생명과학관', 'lat': 37.885257, 'lng':127.735877},
    {'id': '', 'name':'국제회의관', 'lat': 37.884047, 'lng':127.738402},
    {'id': '', 'name':'기초교육관', 'lat': 37.888538, 'lng':127.738090},
    {'id': '', 'name':'학군단', 'lat': 37.888348, 'lng':127.739061},
    {'id': 'Domitory 1', 'name':'학생생황관 1관', 'lat': 37.885590, 'lng':127.740754},
    {'id': 'Domitory 2', 'name':'학생생활관 2관', 'lat': 37.885925, 'lng':127.740681},
    {'id': 'Domitory 3', 'name':'학생생활관 3관', 'lat': 37.885922, 'lng':127.741100},
    {'id': 'Domitory 4', 'name':'학생생활관 4관', 'lat': 37.886272, 'lng': 127/740826},
    {'id': 'Domitory 5', 'name':'학생생활관 5관', 'lat': 37.886304, 'lng': 127.741490},
    {'id': 'Domitory 6', 'name':'학생생활관 6관', 'lat': 37.886128, 'lng': 127.7417799},
    {'id': 'Domitory 7', 'name':'학생생활관 7관', 'lat': 37.886679, 'lng': 127.741563},
    {'id': 'Domitory 8', 'name':'학생생활관 8관', 'lat': 37.887110, 'lng':127.741445},
    {'id': '', 'name':'체육 기자재실', 'lat': 37.887269, 'lng':127.738833},
    {'id': 'H_Stadium','name':'H Stadium(테니스장, 골프장, 농구장, 풋살장)', 'lat': 37.888222, 'lng':127.737337},
    {'id': 'Out_Tennis', 'name':'테니스장', 'lat': 37.888222, 'lng': 127.737337},
    {'id': 'Golf', 'name':'골프장', 'lat': 37.887889, 'lng': 127.736779},
    {'id': 'Baseball', 'name':'농구장', 'lat': 37.887543, 'lng':127.737632},
    {'id': 'Futsal', 'name':'풋살장', 'lat': 37.888528, 'lng':127.739594},
    {'id': 'ILSONG_Stadium', 'name':'ILSONG Stadium', 'lat': 37.887882, 'lng':127.739833},
    {'id': 'In_Tennis', 'name':'실내테니스장', 'lat': 37.887489, 'lng':127.741212},
    {'id': '', 'name': '씨름장', 'lat': 37.887620, 'lng': 127.740788},
    {'id': '', 'name': '온실', 'lat': 37.886653, 'lng':127.735593},
    {'id': 'Hallym_Hospital', 'name':'한림대학교 춘천성심병원', 'lat': 37.883988, 'lng': 127.739875},
    {'id': 'Parking_lot', 'name':'주차장', 'lat': 37.884829, 'lng': 127.738863}
}
]

# 건물 경로를 보여주는 데아터
hallym_routes = {
    'main_gate_to_library': {
        'start': '정문', 
        'end': '도서관', 
        'routes': [
            {
                'summary': '빠른 직선 경로',
                'distance': '350m',
                'steps': [ # Flutter의 _directionsSteps 구조와 유사하게 만듬
                    {'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': ''},
                    {'instructions': '인문 1관에서 사색의 길을 걷다가 자회전합니다.', 'distance': '150m'},
                    {'instructions': '도서관 후문에 도착합니다.', 'distance': '100m'},
                ]
            }, 
            {
                'summary': '경치 좋은 길 (약간 우회)',
                'distance': '450m',
                'steps': [
                    {'instructions': '정문에서 으로 갑니다.', 'distance': '200m'},
                    {'instructions': '일송 기념 도서관 정문으로 진입합니다.', 'distance': '250m'},
                ]
            }
        ]
    },
    'main_gate to CLC': {
        'start': '정문', 
        'end': 'CLC', 
        'routes': [
            {
                'summary': '직선 경로',
                'distance': '300m',
                'steps': [
                    {'instructions': '정문에서 직진하여 CLC 방향으로 갑니다.', 'distance': '300m'},
                ]
            },
            {
                'summary': '사색의 길 경유 경로',
                'distance': '400m',
                'steps': [
                    {'instructions': '정문에서 사색의 길로 진입합니다.', 'distance': '200m'},
                    {'instructions': '사색의 길을 따라 걷다가 CLC로 진입합니다.', 'distance': '200m'},
                ]
            }
        ]
    },
    'main_gate_to_engineering': {
        'start': '정문', 
        'end': '공학관', 
        'routes': [
            {
                'summary': '직선 경로',
                'distance': '600m',
                'steps': [
                    {'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '300m'},
                    {'instructions': 'CLC에서 좌회전하여 공학관 방향으로 갑니다.', 'distance': '300m'},
                ]
            },
            {
                'summary': '자연과학관 경유 경로',
                'distance': '750m',
                'steps': [
                    {'instructions': '도서관을 나와서 사색의 길로 진입합니다.', 'distance': '250m'},
                    {'instructions': '생명의 숲을 지나 계단을 올라가 공학관으로 갑니다.', 'distance': '500m'},
                ]
            }
        ]
    },
    'main_gate_to_dormitory': {
        'start': '정문',
        'end': '학생생활관 8관',
        'routes': [
            {
                'summary': '직선 경로',
                'distance': '500m',
                'steps': [
                    {'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '300m'},
                    {'instructions': 'CLC에서 우회전하여 학생생활관 방향으로 갑니다.', 'distance': '200m'},
                ]
            },
            {
                'summary': '운동장 경로',
                'distance': '650m',
                'steps': [
                    {'instructions': 'CLC 옆에 있는 도로로 진입합니다.', 'distance': '250m'},
                    {'instructions': '도로의 길을 따라가다가 자회전해서 학생생활관으로 진입합니다.', 'distance': '400m'},
                ]
            }
        ]    
    },
    'Dorm_to_engineering': {
        'start': '학생생활관', 
        'end': '공학관 1', 
        'routes': [
            {
                'summary': '계단 이용 최단 경로',
                'distance': '700m',
                'steps': [
                    {'instructions': '학생생활관에서 CLC 쪽으로 내려갑니다.', 'distance': '150m'},
                    {'instructions': '사색의 길을 지나다가  생명과학관과 자연과학관 사이 계단으로 진입합니다.', 'distance': '300m'},
                    {'instructions': '일송정원을 가로질러 공학관 1에 도착합니다.', 'distance': '250m'},
                ]
            },
        ]
    },
    'library_to_hospital': {
        'start': '도서관',
        'end': '한림대학교 춘천성심병원',
        'routes': [
            {   
                'summary': '직선 경로',
                'distance': '1.2km',
                'steps': [
                    {'instructions': '도서관에서 정문 방향으로 직진합니다.', 'distance': '350m'},
                    {'instructions': '정문에서 좌회전하여 병원 방향으로 갑니다.', 'distance': '850m'},
                ]
            },]
    },

    # ... 나머지 경로도 이 형식에 맞춰 데이터 추가 ...
}

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
