# backend/nutrition/app.py

from flask import Flask, jsonify, request
from flask_cors import CORS
import json
import os
import sys
from datetime import datetime

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from nutrition_api import generate_final_response, NUTRITION_MANUAL_DB 

app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False # 한글 깨짐 방지
CORS(app) 

# ==============================================================================
# 1. 고정 메뉴 정의 (365일 항상 나오는 메뉴)
# ==============================================================================
FIXED_DAILY_MENU = {
    "Health (상시 제공)": {
        "종일": ["양상추샐러드드래싱", "깍두기"] 
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
    }
}

# ==============================================================================
# 3. API 엔드포인트 (자동 병합 로직)
# ==============================================================================
@app.route('/api/cafeteria/menu', methods=['GET'])
def get_cafeteria_menu():
    today_date_str = datetime.now().strftime("%Y-%m-%d")
    
    # 1. 오늘의 변동 메뉴(휘당, Chef&U) 가져오기
    # .copy()를 써서 원본 데이터를 보호합니다.
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

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)