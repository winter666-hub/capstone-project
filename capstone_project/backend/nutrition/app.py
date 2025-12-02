# backend/nutrition/app.py

from flask import Flask, jsonify, request
from flask_cors import CORS
import json
import os
import sys
from datetime import datetime

# [경로 설정] bus 폴더 경로 추가
current_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.dirname(current_dir)
sys.path.append(current_dir)
sys.path.append(os.path.join(backend_dir, 'bus'))

# [모듈 임포트]
from nutrition_api import generate_final_response, NUTRITION_MANUAL_DB 
from bus_api import get_realtime_bus_arrival 

app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False 
CORS(app)

# ==============================================================================
# 1. 고정 메뉴 정의 (365일 항상 나오는 메뉴)
# ==============================================================================
FIXED_DAILY_MENU = {
    "Health (상시 제공)": {
        "매일": ["양상추샐러드드래싱", "깍두기"] 
    }
}

# ==============================================================================
# 2. 날짜별 변동 메뉴 (휘당, Chef & U만 입력)
# ==============================================================================
MENU_BY_DATE_DB = {
    # 2025년 11월 26일 (수)
    "2025-11-26": {
        "휘당": {
            "아침": ["코다리조림", "잡곡밥", "맑은순두부찌개", "멸치볶음", "양파채무침", "배추김치"],
            "점심": ["오돈불고기", "잡곡밥", "미역국", "알감자조림", "마늘쫑무침", "상추겉절이"]
        },
        "Chef & U": {
            "점심": ["돈까스하야라이스", "맑은우동국물", "오징어링", "푸질리샐러드", "단무지"]
        }
        # Casa PAN 등 다른 코너는 입력하지 않음
    },
    
    # 2025년 11월 27일 (목)
    "2025-11-27": {
        "휘당": {
            "아침": ["대구육개장", "잡곡밥", "해물순대전", "느타리버섯볶음", "깻잎무침", "배추김치"],
            "점심": ["제육덮밥", "시금치된장찌개", "양파간장조림", "참나물무침", "도토리묵무침"]
        },
        "Chef & U": {
            "점심": ["데리야끼닭갈비덮밥", "팽이장국", "고구마맛탕", "청포도맛젤리", "단무지무침"]
        }
    },
    
    # 2025년 11월 28일 (금)
    "2025-11-28": {
        "휘당": {
            "아침": ["감자수제비국", "잡곡밥", "돈사태찜", "가지나물", "오이지무침", "배추김치"],
            "점심": ["얼큰순대국", "잡곡밥", "메밀전병", "우엉조림", "참나물무침"]
        },
        "Chef & U": {
            "점심": ["마파두부덮밥", "탕파국", "꼬마찐빵", "후르츠샐러드", "무비트피클"]
        }
    },
    "2025-11-29": {
        "휘당": {
            "점심": ["운영 없음 (주말)"] 
        },
        "Chef & U": {
            "점심": ["운영 없음 (주말)"]
        }
    },
    
    # 2025년 11월 30일 (일)
    "2025-11-30": {
        "휘당": {
            "점심": ["운영 없음 (주말)"] 
        },
        "Chef & U": {
            "점심": ["운영 없음 (주말)"]
        }
    }
    # 🚨 [여기까지 추가]
}


# ==============================================================================
# 3. API 엔드포인트 (자동 병합 로직)
# ==============================================================================
@app.route('/api/cafeteria/menu', methods=['GET'])
def get_cafeteria_menu():
    today_date_str = datetime.now().strftime("%Y-%m-%d")
    today_menu_data = MENU_BY_DATE_DB.get(today_date_str, {}).copy()
    
    if not today_menu_data:
        return jsonify({"error": f"날짜({today_date_str})에 해당하는 메뉴를 찾을 수 없습니다."}), 404

    # 2. [핵심] 고정 메뉴(Health)를 오늘 메뉴에 합치기
    # 이렇게 하면 매일 입력하지 않아도 항상 Health 코너가 같이 나갑니다.
    today_menu_data.update(FIXED_DAILY_MENU)

    try:
        # 3. 합쳐진 전체 데이터를 처리 함수로 전달
        json_string = generate_final_response(today_menu_data)
        
        response_data = json.loads(json_string)
        response_data['날짜'] = today_date_str 
        
        return jsonify(response_data), 200

    except Exception as e:
        app.logger.error(f"API 처리 오류 발생: {e}")
        return jsonify({"error": "데이터 처리 중 서버 오류 발생", "detail": str(e)}), 500



# 지도 구현 ==========================================================================
hallym_buildings = [
    {'id': 'main_gate', 'name': '정문', 'lat': 37.883970, 'lng': 127.737828, 'imageUrl': ''},
    {'id': 'CLC', 'name': 'Campus Life Center', 'lat': 37.886730, 'lng': 127.740115, 'imageUrl': ''},
    {'id': 'international', 'name': '국제관', 'lat': 37.886737, 'lng': 127.740924, 'imageUrl': ''},
    {'id': 'engineering', 'name': '공학관', 'lat': 37.886341, 'lng': 127.735815, 'imageUrl': ''},
    {'id': 'social_science_first', 'name': '사회경영1관', 'lat': 37.888278, 'lng': 127.738239, 'imageUrl': ''},
    {'id': 'Hallym_Rec_Center', 'name': '한림레크리에이션센터', 'lat': 37.884616, 'lng': 127.738773, 'imageUrl': ''},
    {'id': 'library', 'name': '일송기념도서관', 'lat': 37.886972, 'lng': 127.738153, 'imageUrl': ''},
    
    # 학내 주요 건물 및 시설물
    {'id': 'main_hall_humanities_1', 'name': '대학본부인문1관', 'lat': 37.886552, 'lng': 127.737988, 'imageUrl': ''},
    {'id': 'humanities_2', 'name': '인문2관', 'lat': 37.886359, 'lng': 127.737371, 'imageUrl': ''},
    {'id': 'Ilsong_ArtHall', 'name': '일송아트홀', 'lat': 37.887029, 'lng': 127.737003, 'imageUrl': ''},
    {'id': 'med_bio_research', 'name': '의료바이오융합연구원', 'lat': 37.885969, 'lng': 127.737688, 'imageUrl': ''},
    {'id': 'sasaek_gil', 'name': '사색의길', 'lat': 37.885446, 'lng': 127.737161, 'imageUrl': ''},
    {'id': 'forest_of_life', 'name': '생명의숲', 'lat': 37.885453, 'lng': 127.736249, 'imageUrl': ''},
    {'id': 'ilsong_garden', 'name': '일송정원', 'lat': 37.886007, 'lng': 127.736013, 'imageUrl': ''},
    {'id': 'medicine_hall', 'name': '의학관', 'lat': 37.885974, 'lng': 127.737267, 'imageUrl': ''},
    {'id': 'main_hall_annex', 'name': '대학본부별관', 'lat': 37.886644, 'lng': 127.738688, 'imageUrl': ''},
    {'id': 'social_science_second', 'name': '사회경영2관', 'lat': 37.887804, 'lng': 127.738344, 'imageUrl': ''},
    {'id': 'natural_science', 'name': '자연과학관', 'lat': 37.885827, 'lng': 127.736789, 'imageUrl': ''},
    {'id': 'life_science', 'name': '생명과학관', 'lat': 37.885257, 'lng': 127.735877, 'imageUrl': ''},
    {'id': 'international_conf', 'name': '국제회의관', 'lat': 37.884047, 'lng': 127.738402, 'imageUrl': ''},
    {'id': 'basic_education', 'name': '기초교육관', 'lat': 37.888538, 'lng': 127.738090, 'imageUrl': ''},
    
    
    # 학생생활관 (Domitory ID 수정)
    {'id': 'dorm_1', 'name': '학생생활관 1관', 'lat': 37.885590, 'lng': 127.740754, 'imageUrl': ''},
    {'id': 'dorm_2', 'name': '학생생활관 2관', 'lat': 37.885925, 'lng': 127.740681, 'imageUrl': ''},
    {'id': 'dorm_3', 'name': '학생생활관 3관', 'lat': 37.885922, 'lng': 127.741100, 'imageUrl': ''},
    {'id': 'dorm_4', 'name': '학생생활관 4관', 'lat': 37.886272, 'lng': 127.740826, 'imageUrl': ''},
    {'id': 'dorm_5', 'name': '학생생활관 5관', 'lat': 37.886304, 'lng': 127.741490, 'imageUrl': ''},
    {'id': 'dorm_6', 'name': '학생생활관 6관', 'lat': 37.886128, 'lng': 127.741779, 'imageUrl': ''},
    {'id': 'dorm_7', 'name': '학생생활관 7관', 'lat': 37.886679, 'lng': 127.741563, 'imageUrl': ''},
    {'id': 'dorm_8', 'name': '학생생활관 8관', 'lat': 37.887110, 'lng': 127.741445, 'imageUrl': ''},
    # 체육 시설 및 기타
    {'id': 'sports_equipment', 'name': '체육 기자재실', 'lat': 37.887414, 'lng': 127.738818, 'imageUrl': ''},
    {'id': 'Out_Tennis', 'name': '실외 테니스장', 'lat': 37.888222, 'lng': 127.737337, 'imageUrl': ''},
    {'id': 'Golf_range', 'name': '골프 연습장', 'lat': 37.887889, 'lng': 127.736779, 'imageUrl': ''},
    {'id': 'Basketball_court', 'name': '농구장', 'lat': 37.887543, 'lng': 127.737632, 'imageUrl': ''},
    {'id': 'ILSONG_Stadium', 'name': 'ILSONG Stadium', 'lat': 37.887882, 'lng': 127.739833, 'imageUrl': ''},
    {'id': 'In_Tennis', 'name': '실내테니스장', 'lat': 37.887489, 'lng': 127.741212, 'imageUrl': ''},
    {'id': 'ssireum_ring', 'name': '씨름장', 'lat': 37.887620, 'lng': 127.740788, 'imageUrl': ''},
    {'id': 'Hallym_Hospital', 'name': '한림대학교 춘천성심병원', 'lat': 37.883988, 'lng': 127.739875, 'imageUrl': ''},
    {'id': 'Parking_lot_1', 'name': '주차장 1', 'lat': 37.884829, 'lng': 127.738863, 'imageUrl': ''}
]

# =========================================================
# 🛣️ 한림대학교 경로 데이터 (ID_to_ID 키 형식으로 통일)
# =========================================================
Hallym_Routes = {
    # 7. 정문 -> 일송기념도서관
    'main_gate_to_library': { 
        'start': '정문', 
        'end': '일송기념도서관',
        'routes': [
             {
                 'summary': '빠른 경로',
                 'distance': '450m', 
                 'steps': [
                     {'instructions': '정문에서 포세이돈 분수 쪽으로 갑니다.', 'distance': '200m'},
                     {'instructions': '계단을 올라 일송 기념 도서관 정문으로 진입합니다.', 'distance': '250m'}
                 ]
             }, 
             {
                 'summary': '우회 경로',
                 'distance': '450m',
                 'steps': [ 
                     {'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '200m'},
                     {'instructions': '인문 1관에서 사색의 길을 걷다가 좌회전합니다.', 'distance': '150m'},
                     {'instructions': '도서관 후문에 도착합니다.', 'distance': '100m'}
                 ]
             }
        ]
    },

    # CLC
    'main_gate_to_CLC': {
        'start': '정문', 
        'end': 'Campus Life Center', 
        'routes': [
             {
                 'summary': '빠른 경로',
                 'distance': '300m',
                 'steps': [
                     {'instructions': '정문에서 직진하여 길을 따라갑니다.', 'distance': '50m'},
                     {'instructions': '우회전하여 CLC 방향으로 직진합니다.', 'distance': '250m'},
                 ]
             },
             {
                 'summary': '우회 경로',
                 'distance': '400m',
                 'steps': [
                     {'instructions': '도서관 방향으로 가면서 도서관 1층에 있는 열람실 옆쪽 계단으로 걸어올라갑니다', 'distance': '200m'},
                     {'instructions': '계단을 다 올라간 다음 인문1관 앞을 지나쳐 CLC 방향으로 직진합니다.', 'distance': '200m'},
                 ]
             }
        ]
    },
    
    # 공학관
    'main_gate_to_engineering': { 
        'start': '정문', 
        'end': '공학관', 
        'routes': [
             {
                 'summary': '가장 빠른 경로',
                 'distance': '600m', 
                 'steps': [
                     {'instructions': '정문에서 도서관으로 직진합니다.', 'distance': '100m'},
                     {'instructions': '도서관 안으로 들어간 다음 왼쪽에 있는 엘리베이터에 탑승합니다.', 'distance': '200m'},
                     {'instructions': '4층으로 올라가 도서관을 나와서 사색의 길로 진입합니다.', 'distance': '200m'},
                     {'instructions': '생명의 숲을 지나 계단을 올라가 공학관으로 갑니다.', 'distance': '100m'},
                 ]
             },
             {
                 'summary': '우회경로',
                 'distance': '600m', 
                 'steps': [
                     {'instructions': '정문에서 도서관으로 직진합니다.', 'distance': '100m'},
                     {'instructions': '도서관 안으로 들어간 다음 왼쪽에 있는 엘리베이터에 탑승합니다.', 'distance': '200m'},
                     {'instructions': '4층으로 올라가 도서관을 나와서 자연공학관 사이에 있는 계단으로 올라갑니다.', 'distance': '200m'},
                     {'instructions': '계단에서 좌회전해서 공학관 방향으로 갑니다.', 'distance': '100m'},
                 ]
             }
        ]
    },


    # 1. 정문 -> 대학본부인문1관
    'main_gate_to_main_hall_humanities_1': { 
        'start': '정문',
        'end': '대학본부인문1관',
        'routes': [
             {
                 'summary': '직선 경로',
                 'distance': '400m',
                 'steps': [
                     {'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '200m'},
                     {'instructions': '우회전해서 대학본부인문1관에 도착합니다.', 'distance': '200m'},
                 ]
             },
        ]
    },
    
    # 2. 정문 -> 학생생활관 8관
    'main_gate_to_dorm_8': {
        'start': '정문',
        'end': '학생생활관 8관',
        'routes': [
             {
                 'summary': '직선 경로',
                 'distance': '500m',
                 'steps': [
                     {'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '300m'},
                     {'instructions': 'CLC에서 우회전해서 가다가 학생생활관 방향으로 갑니다.', 'distance': '200m'},
                 ]
             },
             {
                 'summary': '운동장 경로',
                 'distance': '650m',
                 'steps': [
                     {'instructions': 'CLC 옆에 있는 도로로 진입합니다.', 'distance': '250m'},
                     {'instructions': '도로의 길을 따라가다가 좌회전해서 학생생활관으로 진입합니다.', 'distance': '400m'},
                 ]
             }
        ]
    },
    
    # 3. 학생생활관 1관 -> 공학관
    'dorm_1_to_engineering': {
        'start': '학생생활관 1관',
        'end': '공학관',
        'routes': [
             {
                 'summary': '계단 이용 최단 경로',
                 'distance': '700m',
                 'steps': [
                     {'instructions': '학생생활관 1관에서 CLC 쪽으로 내려갑니다.', 'distance': '150m'},
                     {'instructions': '사색의 길을 지나다가 생명과학관과 자연과학관 사이 계단으로 진입합니다.', 'distance': '300m'},
                     {'instructions': '일송정원을 가로질러 공학관에 도착합니다.', 'distance': '250m'},
                 ]
             },
        ]
    },
    
    # 4. 정문 -> 국제관
    'main_gate_to_international': { 
        'start': '정문',
        'end': '국제관',
        'routes': [
             {
                 'summary': '직선 경로',
                 'distance': '650m',
                 'steps': [
                     {'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '300m'},
                     {'instructions': 'CLC에서 우회전하다가 좌회전해 국제관 방향으로 갑니다.', 'distance': '50m'},
                     {'instructions': 'CLC 옆에 있는 도로를 따라 내려가면 국제관에 도착합니다.', 'distance': '300m'}, 
                 ]
             },
             {
                 'summary': '우회 경로',
                 'distance': '650m',
                 'steps': [
                     {'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '200m'},
                     {'instructions': 'CLC 안으로 들어가 1층까지 내려간 다음 좌회전한 다음 밖으로 나옵니다.', 'distance': '250m'},
                     {'instructions': '나와서 왼쪽에 보이는 계단을 내려가 국제관 방향으로 갑니다.', 'distance': '200m'},
                 ]
             }
        ]
    },

    # 5. 정문 -> 사회경영1관
    'main_gate_to_social_science_first': { 
        'start': '정문',
        'end': '사회경영1관',
        'routes': [
             { 
                 'summary': '직선 경로',
                 'distance': '500m',
                 'steps': [
                     {'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '200m'},
                     {'instructions': 'CLC에서 우회전해서 길을 따라 사회경영1관으로 갑니다.', 'distance': '200m'},
                     {'instructions': '길을 따라 카페가 있는 곳이 사회경영1관입니다.', 'distance': '100m'},
                 ]
             }
        ]
    },
    
    # 6. 정문 -> 사회경영2관
    'main_gate_to_social_science_second': { 
        'start': '정문',
        'end': '사회경영2관',
        'routes': [
             {
                 'summary': '직선 경로',
                 'distance': '1050m',
                 'steps': [
                     {'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '400m'},
                     {'instructions': 'CLC에서 우회전해서 길을 따라 사회경영2관으로 갑니다.', 'distance': '450m'},
                     {'instructions': '길을 따라 쭉 가면 사회경영2관입니다.', 'distance': '200m'},
                 ]
             },
        ]
    },

    # 8. 정문 -> 학생생활관 1관
    'main_gate_to_dorm_1': 
    { 'start': '정문', 
      'end': '학생생활관 1관', 
      'routes': [{ 'summary': '직선 경로', 
                    'distance': '300m', 
                    'steps': [{'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '100m'}, 
                              {'instructions': 'CLC에서 우회전해서 가다가 좌회전해서 학생생활관 방향으로 갑니다.', 'distance': '75m'}, 
                              {'instructions': '직진하다가 학생생활관 1관에 도착합니다.', 'distance': '125m'}]}]},
    
    # 9. 정문 -> 학생생활관 2관
    'main_gate_to_dorm_2': 
    { 'start': '정문', 
     'end': '학생생활관 2관', 
      'routes': [{ 'summary': '직선 경로', 
                    'distance': '375m', 
                    'steps': [{'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '150m'}, 
                              {'instructions': 'CLC에서 우회전해서 가다가 좌회전해서 학생생활관 방향으로 갑니다.', 'distance': '100m'}, 
                              {'instructions': '직진하다가 학생생활관 2관에 도착합니다.', 'distance': '125m'},
]
}]},
    
    # 10. 정문 -> 학생생활관 3관
    'main_gate_to_dorm_3': 
    { 'start': '정문', 
    'end': '학생생활관 3관', 
      'routes': [{ 'summary': '직선 경로', 
                  'distance': '450m', 
                  'steps': [{'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '200m'}, 
                            {'instructions': 'CLC에서 우회전해서 가다가 좌회전해서 학생생활관 방향으로 갑니다.', 'distance': '125m'}, 
                            {'instructions': '직진하다가 학생생활관 3관에 도착합니다.', 'distance': '125m'}]}]}, 
    
    # 11. 정문 -> 학생생활관 4관
    'main_gate_to_dorm_4': 
    { 'start': '정문', 
     'end': '학생생활관 4관', 
      'routes': [{ 'summary': '직선 경로', 
                    'distance': '525m', 
                    'steps': [{'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '250m'}, 
                              {'instructions': 'CLC에서 우회전해서 가다가 좌회전해서 학생생활관 방향으로 갑니다.', 'distance': '150m'}, 
                              {'instructions': '직진하다가 학생생활관 4관에 도착합니다.', 'distance': '125m'}]}]},
    
    # 12. 정문 -> 학생생활관 5관
    'main_gate_to_dorm_5': 
    { 'start': '정문', 
     'end': '학생생활관 5관', 
      'routes': [{ 'summary': '직선 경로', 
                    'distance': '600m', 
                    'steps': [{'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '300m'}, 
                              {'instructions': 'CLC에서 우회전해서 가다가 좌회전해서 학생생활관 방향으로 갑니다.', 'distance': '175m'}, 
                              {'instructions': '직진하다가 학생생활관 5관에 도착합니다.', 'distance': '125m'}]}]}, 
    
    # 13. 정문 -> 학생생활관 6관
    'main_gate_to_dorm_6': { 
        'start': '정문', 
        'end': '학생생활관 6관', 
        'routes': [
             { 'summary': '직선 경로', 
             'distance': '675m', 
                         'steps': [{'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '350m'}, 
                                   {'instructions': 'CLC에서 우회전해서 가다가 좌회전해서 학생생활관 방향으로 갑니다.', 'distance': '200m'}, 
                                   {'instructions': '직진하다가 학생생활관 6관에 도착합니다.', 'distance': '125m'}]}]}, 
    
    # 14. 정문 -> 학생생활관 7관
    'main_gate_to_dorm_7': {
        'start': '정문', 
        'end': '학생생활관 7관',
        'routes': [
             { 
                 'summary': '직선 경로', 
                 'distance': '750m',
                 'steps': [
                     {'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '400m'},
                     {'instructions': 'CLC에서 우회전해서 가다가 좌회전해서 학생생활관 방향으로 갑니다.', 'distance': '225m'},
                     {'instructions': '직진하다가 학생생활관 7관에 도착합니다.', 'distance': '125m'},
                 ]
             },
        ]
    },

    # 15. 정문 -> 대학본부별관
    'main_gate_to_main_hall_annex': {
        'start': '정문',
        'end': '대학본부별관',
        'routes': [
             {
             'summary': '직선 경로',
             'distance': '300m',
             'steps': [
                 {'instructions': '정문에서 인문1관 방향으로 직진합니다.', 'distance': '200m'},
                 {'instructions': '인문1관에서 오른쪽에 있는 건물이 대학본부별관입니다', 'distance': '100m'},
                 ]
             }
        ]
    },
    
    # 16. 정문 -> 의료바이오융합연구원
    'main_gate_to_med_bio_research': {
        'start': '정문',
        'end': '의료바이오융합연구원',
        'routes': [{'summary': '직선 경로', 'distance': '450m', 'steps': [{'instructions': '정문에서 인문1관 방향으로 직진합니다.', 'distance': '200m'}, 
                                                               {'instructions': '우회전하여 의료바이오융합연구원이 보입니다.', 'distance': '250m'}]},
        ]
    },

    # 17. 정문 -> 일송아트홀
    'main_gate_to_Ilsong_ArtHall': {
        'start': '정문',
        'end': '일송아트홀',
        'routes': [
             {'summary': '직선 경로', 'distance': '400m', 'steps': [{'instructions': '정문에서 포세이돈 분수 쪽으로 갑니다.', 'distance': '200m'}, 
                                                               {'instructions': '분수를 지나 도서관 옆에 있는 계단을 타고 올라갑니다.', 'distance': '100m'},
                                                               {'instructions': '계단을 올라가 자연과학관 중간에 있는 계단을 올라가면 일송아트홀이 보입니다.', 'distance': '100m'}],},
        ]
    },

    # 18. 정문 -> 인문2관
    'main_gate_to_humanities_2': {
        'start': '정문',
        'end': '인문2관',
        'routes': [
             {'summary': '직선 경로', 'distance': '550m', 'steps': [{'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '350m'}, {'instructions': '인문 1관을 지나 계단을 올라갑니다.', 'distance': '200m'}]},
        ]
    },
    
    # 19. 정문 -> 한림대학교 춘천성심병원
    'main_gate_to_Hallym_Hospital': { 
        'start': '정문', 
        'end': '한림대학교 춘천성심병원', 
        'routes': [{'summary': '직선 경로', 
                    'distance': '500m', 
                    'steps': [{'instructions': '정문에서 좌회전하여 병원 방향으로 갑니다.', 'distance': '500m'}]}]},
    
    # 20. 정문 -> 주차장 1
    'main_gate_to_Parking_lot_1': { 
        'start': '정문', 
        'end': '주차장 1', 
        'routes': [{'summary': '직선 경로', 
                    'distance': '400m', 
                    'steps': [{'instructions': '정문에서 올라가다가 국제회의관 방향으로 우회전하여 주차장 방향으로 갑니다.', 'distance': '400m'}]}]},
    
    # 21. 정문 -> ILSONG Stadium
    'main_gate_to_ILSONG_Stadium': { 
        'start': '정문', 
        'end': 'ILSONG Stadium', 
        'routes': [{ 'summary': '직선 경로', 
                    'distance': '800m', 
                    'steps': [{'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '400m'}, 
                              {'instructions': 'CLC에서 오른쪽으로 걸어가다가 왼쪽에 있는 계단을 타고 내려가면 Ilsong Stadium 방향으로 갑니다.', 'distance': '400m'}]}]},

    
    # 23. 정문 -> 자연과학관
    'main_gate_to_natural_science': { 
        'start': '정문', 
        'end': '자연과학관', 
        'routes': [{'summary': '직선 경로', 
                    'distance': '550m', 
                    'steps': [{'instructions': '정문에서 도서관 방향으로 직진합니다.', 'distance': '300m'}, 
                              {'instructions': '도서관 옆에 있는 계단을 타고 자연과학관 방향으로 갑니다.', 'distance': '250m'}]}]},
    
    # 24. 정문 -> 생명과학관
    'main_gate_to_life_science': { 
        'start': '정문', 
        'end': '생명과학관', 
        'routes': [{'summary': '직선 경로', 
                    'distance': '600m', 
                    'steps': [{'instructions': '정문에서 도서관 방향으로 직진합니다.', 'distance': '350m'}, 
                              {'instructions': '도서관 옆에 있는 계단을 타고 생명과학관 방향으로 갑니다.', 'distance': '250m'}]}]},
    
    # 25. 정문 -> 의학관
    'main_gate_to_medicine_hall': { 
        'start': '정문', 
        'end': '의학관', 
        'routes': [{'summary': '직선 경로', 
                    'distance': '550m', 
                    'steps': [{'instructions': '정문에서 인문1관 방향으로 직진합니다.', 'distance': '300m'}, 
                              {'instructions': '의료바이오융합연구원 쪽으로 좌회전해서 인문1관과의 사이에 있는 계단을 타고 올라갑니다.', 'distance': '250m'}]}]},
    
    # 26. 정문 -> 기초교육관
    'main_gate_to_basic_education': { 
        'start': '정문', 
        'end': '기초교육관', 
        'routes': [{'summary': '직선 경로', 
                    'distance': '850m', 
                    'steps': [{'instructions': '정문에서 CLC 방향으로 직진합니다.', 'distance': '400m'}, 
                              {'instructions': 'CLC에서 우회전해서 길을 따라 기초교육관으로 갑니다.', 'distance': '450m'}]}]},
    
    # 27. 정문 -> 국제회의관
    'main_gate_to_international_conf': { 
        'start': '정문', 
        'end': '국제회의관', 
        'routes': [{'summary': '직선 경로', 
                    'distance': '300m', 
                    'steps': [{'instructions': '정문에서 좌회전하여 국제회의관(우리은행이 있는 건물)으로 갑니다.', 'distance': '300m'}]}]},
    
    # 28. 정문 -> 한림레크리에이션센터
    'main_gate_to_Hallym_Rec_Center': { 
        'start': '정문', 
        'end': '한림레크리에이션센터', 
        'routes': [{'summary': '직선 경로', 
                    'distance': '450m', 
                    'steps': [{'instructions': '정문에서 도서관까지 간 다음 왼쪽으로 꺽어 한림레크리에이션센터로 갑니다.', 'distance': '250m'}]}]},
}


# =========================================================
# ⚙️ 헬퍼 함수
# =========================================================

def get_building_id(name):
    """건물 이름을 받아 해당하는 ID를 반환합니다."""
    for b in hallym_buildings:
        if b['name'] == name:
            return b['id']
    return None

# =========================================================
# 🌐 API 엔드포인트 정의
# =========================================================

@app.route('/buildings', methods=['GET'])
def get_buildings():
    """캠퍼스 건물 목록(이름, 위치 정보 포함)을 JSON 형식으로 반환합니다. (GET 요청)"""
    # hallym_buildings 데이터를 JSON으로 반환
    return jsonify(hallym_buildings)

@app.route('/directions', methods=['GET'])
def get_directions():
    """
    출발지 이름(originName)과 도착지 이름(destName)을 받아
    사전 정의된 경로 정보를 JSON 형식으로 반환합니다.
    """
    origin_name = request.args.get('originName')
    dest_name = request.args.get('destName')

    if not origin_name or not dest_name:
        # 요청 매개변수가 부족한 경우
        return jsonify({"message": "출발지(originName)와 도착지(destName)를 모두 제공해야 합니다."}), 400

    # 1. 한글 이름으로 건물 ID를 찾습니다.
    origin_id = get_building_id(origin_name)
    dest_id = get_building_id(dest_name)
    
    if not origin_id or not dest_id:
        # 건물 이름이 목록에 없는 경우
        return jsonify({"message": f"요청된 출발지({origin_name}) 또는 도착지({dest_name})를 건물 목록에서 찾을 수 없습니다."}), 404

    # 2. 경로 딕셔너리에서 사용할 키를 생성합니다. (ID_to_ID 형식)
    route_key = f"{origin_id}_to_{dest_id}"
    
    directions = Hallym_Routes.get(route_key)

    if not directions:
        # 요청된 순서의 경로가 없는 경우, 역방향 경로를 시도합니다.
        reverse_route_key = f"{dest_id}_to_{origin_id}"
        directions = Hallym_Routes.get(reverse_route_key)
        
        if not directions:
            # 순방향/역방향 모두 경로 데이터가 없는 경우
            return jsonify({
                "message": f"요청된 경로 ({origin_name} -> {dest_name})에 대한 데이터가 서버에 없습니다.", 
                "checked_keys": [route_key, reverse_route_key]
            }), 404
        
        # 역방향 경로를 찾았을 경우, UI에서 출발/도착을 맞출 수 있도록 이름만 수정합니다.
        # 실제 길 안내 단계(steps)는 클라이언트에서 역순 처리해야 할 수 있습니다.
        directions['start'] = origin_name
        directions['end'] = dest_name

    # 3. 경로 데이터를 JSON 형식으로 반환
    return jsonify(directions)

@app.route('/', methods=['GET'])
def index():
    """기본 접속 페이지입니다. API 사용법을 안내하는 JSON을 반환합니다."""
    return jsonify({
        "message": "한림대학교 길찾기 API 서버가 실행 중입니다.",
        "endpoints": {
            "/buildings": "GET 요청: 전체 건물 목록을 반환합니다.",
            "/directions": "GET 요청: 경로 정보를 반환합니다. (필수 쿼리: ?originName=<출발지>&destName=<도착지>)",
            "example_query": "/directions?originName=정문&destName=일송기념도서관"
        }
    })
# 3. 버스 API 엔드포인트 추가 ===================================================================
@app.route('/api/bus/arrival', methods=['GET'])
def get_bus_arrival():
    """
    한림대 정류장 실시간 버스 도착 정보를 반환합니다.
    """
    try:
        bus_list = get_realtime_bus_arrival()
        
        return jsonify({
            "status": "success",
            "count": len(bus_list),
            "data": bus_list
        })
    except Exception as e:
        app.logger.error(f"버스 API 오류: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
