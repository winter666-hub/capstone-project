# backend/nutrition/app.py

from flask import Flask, jsonify, request
from flask_cors import CORS # CORS 문제를 해결하기 위해 추가
import json
import os
import sys
from datetime import datetime

#http://127.0.0.1:5000/api/cafeteria/menu

# --- 1. nutrition_api.py 파일 경로 및 함수 임포트 ---
# 같은 디렉토리에 있는 nutrition_api.py에서 필요한 함수와 DB를 가져옵니다.
# sys.path 설정은 환경에 따라 필요 없을 수도 있지만, 안전을 위해 유지합니다.
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from nutrition_api import generate_final_response, NUTRITION_MANUAL_DB 
# NUTRITION_MANUAL_DB는 여기서 직접 사용되진 않지만, 구조상 임포트합니다.

# [TODO]: nutrition_api.py 파일 내에 MENU_BY_DATE_DB를 정의했다면 여기서도 임포트해야 합니다.
# 임시로 app.py 내부에 MENU_BY_DATE_DB를 정의합니다.
MENU_BY_DATE_DB = {
    # 2025년 11월 13일 메뉴 (오늘)
    "2025-11-13": [
        "찹쌀밥", "호박고추장찌개", "만두야채전", "쫄깃무침", "배추김치", "잡곡밥",
        "뼈없는닭갈비", "콩나물국", "오징어채볶음", "오이지무침", "크림스프파스타",
        "단무지", "양상추샐러드/드레싱", "깍두기"
    ],
    # 2025년 11월 14일 메뉴 (내일)
    "2025-11-14": [
        "두부버섯된장국", "잡곡밥", "닭볶음", "옛날잡채", "가자미순살볶음", "오징어채볶음",
        "배추김치", "마파두부덮밥", "팽이장국", "연두부계란찜", "후르츠샐러드", 
        "단무지무침", "양상추샐러드/드레싱", "깍두기"
    ],
    "2025-11-17": [
        "북엇국",
        "잡곡밥",
        "닭가슴살조림",
        "브로콜리숙회",
        "오이지무침",
        "배추김치",
        "제육고추장볶음",
        "시금치된장찌개",
        "도토리묵무침",
        "청포묵김가루무침",
        "참나물무침",
        "꽁치김치찌개",
        "옥수수장으로덮개계란찜",
        "블루베리요플레",
        "아몬드마카롱",
        "마라탕",
        "사모사",
        "츠키멘",
        "소세지라면",
        "양상추샐러드/드레싱",
        "깍두기"
    ],
    # 다른 날짜 메뉴 계속 추가 가능
}
# -------------------------------------------------------------

app = Flask(__name__)
# 프론트엔드(다른 포트나 장치)와의 통신을 허용합니다.
CORS(app) 


# ==============================================================================
# 2. 학식 메뉴 API 엔드포인트 정의
# ==============================================================================
@app.route('/api/cafeteria/menu', methods=['GET'])
def get_cafeteria_menu():
    """ 
    현재 시스템 날짜(오늘)에 해당하는 메뉴만 필터링하여 영양 성분과 함께 반환합니다.
    """
    # 1. 현재 날짜 (YYYY-MM-DD 형식)를 가져옵니다.
    today_date_str = datetime.now().strftime("%Y-%m-%d")
    
    # 2. 날짜별 DB에서 오늘 메뉴 리스트를 가져옵니다.
    today_menu_list = MENU_BY_DATE_DB.get(today_date_str, []) 
    
    if not today_menu_list:
        # 메뉴가 없으면 에러 메시지를 반환합니다.
        return jsonify({"error": f"날짜({today_date_str})에 해당하는 메뉴를 찾을 수 없습니다."}), 404

    try:
        # 3. 오늘 메뉴 리스트를 핵심 함수에 전달하여 영양 정보를 매칭합니다.
        # generate_final_response 함수가 이제 메뉴 리스트를 인자로 받습니다.
        json_string = generate_final_response(today_menu_list)
        
        # JSON 문자열을 딕셔너리로 변환하여 응답 준비
        response_data = json.loads(json_string)
        
        # 최종 응답 데이터의 날짜를 현재 날짜로 설정
        response_data['date'] = today_date_str 
        
        return jsonify(response_data), 200

    except Exception as e:
        app.logger.error(f"API 처리 오류 발생: {e}")
        return jsonify({"error": "데이터 처리 중 서버 오류 발생", "detail": str(e)}), 500


# ==============================================================================
# 3. 서버 실행
# ==============================================================================
if __name__ == '__main__':
    # Flask 서버를 실행합니다. (개발 시 host='0.0.0.0'을 사용해야 외부에서도 접근 가능)
    app.run(debug=True, host='0.0.0.0', port=5000)