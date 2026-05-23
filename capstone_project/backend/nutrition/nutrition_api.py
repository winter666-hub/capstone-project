# backend/nutrition/nutrition_api.py

import json
from datetime import datetime
import os

# ==============================================================================
# 1. 수동 관리 데이터베이스 
# ==============================================================================

# --- 1-1. 밥/메인 메뉴 (Rice/Main Dishes)
RICE_MAIN_DB = {
    # 기존 메뉴
    "잡곡밥": {
        "calorie": "306 kcal", "carbs": "61.6 g", "protein": "11.1 g", "fat": "1.8 g",
        "allergy": "없음", "info": "다이어트 추천",
    },
    "흰쌀밥": {
        "calorie": "300 kcal", "carbs": "65 g", "protein": "6 g", "fat": "0.5 g",
        "allergy": "없음", "info": "흰쌀밥",
    },
    "제육덮밥": {
        "calorie": "716 kcal", "carbs": "79.9 g", "protein": "30.9 g", "fat": "30.3 g",
        "allergy": "돼지고기", "info": "나트륨 함량 높음",
    },
    "소불고기": {
        "calorie": "489 kcal", "carbs": "15 g", "protein": "56.5 g", "fat": "20.5 g",
        "allergy": "쇠고기", "info": "단백질 풍부",
    },
    "잔치국수": {
        "calorie": "265 kcal", "carbs": "48.3 g", "protein": "11.6 g", "fat": "2.9 g",
        "allergy_info": "밀(면)", "info": "나트륨 주의",
    },
    "야채매콤비빔밥": {
        "calorie": "550 kcal", "carbs": "90 g", "protein": "15 g", "fat": "15 g",
        "allergy_info": "고추장, 참기름(대두)", "info": "나트륨 주의 (비빔밥 소스)",
    },
    "간장불고기": {
        "calorie": "489 kcal", "carbs": "15 g", "protein": "56.5 g", "fat": "20.5 g",
        "allergy_info": "쇠고기, 대두(간장)", "info": "고단백",
    },
    "돈사태찜": {
        "calorie": "450 kcal", "carbs": "25 g", "protein": "40 g", "fat": "25 g",
        "allergy_info": "돼지고기, 대두", "info": "단백질/지방 함량 높음",
    },
    "오븐불고기": {
        "calorie": "380 kcal", "carbs": "15 g", "protein": "40 g", "fat": "18 g",
        "allergy_info": "쇠고기", "info": "저지방 불고기",
    },
    "떡볶이": {
        "calorie": "400 kcal", "carbs": "75 g", "protein": "10 g", "fat": "5 g",
        "allergy_info": "밀(떡), 고추장", "info": "탄수화물 높음 (분식)",
    },
    "마파두부덮밥": {
        "calorie": "600 kcal", "carbs": "80 g", "protein": "25 g", "fat": "18 g",
        "allergy_info": "대두(두부), 밀", "info": "두부로 단백질 보충",
    },
    "꽁치김치조림": {
        "calorie": "380 kcal", "carbs": "30 g", "protein": "35 g", "fat": "15 g",
        "allergy_info": "꽁치(어류), 대두", "info": "단백질 풍부, 나트륨 주의",
    },
    "소고기야채죽": {
        "calorie": "280 kcal", "carbs": "45 g", "protein": "15 g", "fat": "5 g",
        "allergy_info": "쇠고기", "info": "부담 없는 아침 식사",
    },
    "잡볶음밥": {
        "calorie": "450 kcal", "carbs": "70 g", "protein": "15 g", "fat": "12 g",
        "allergy_info": "대두", "info": "혼합 채소 포함",
    },
    "해물볶음밥": {
        "calorie": "490 kcal", "carbs": "75 g", "protein": "18 g", "fat": "12 g",
        "allergy_info": "새우, 오징어", "info": "해산물 알레르기 주의",
    },
    "잡채밥": {
        "calorie": "650 kcal", "carbs": "95 g", "protein": "20 g", "fat": "20 g",
        "allergy_info": "밀, 돼지고기", "info": "탄수화물 함량 높음",
    },
    "제육김치볶음밥": {
        "calorie": "680 kcal", "carbs": "85 g", "protein": "30 g", "fat": "25 g",
        "allergy_info": "돼지고기", "info": "나트륨/지방 함량 높음",
    },
    "눈꽃치즈닭갈비덮밥": {
        "calorie": "780 kcal", "carbs": "90 g", "protein": "45 g", "fat": "30 g",
        "allergy_info": "닭고기, 유제품(치즈)", "info": "고칼로리 메인 메뉴",
    },
    "야채비빔냉국수": {
        "calorie": "420 kcal", "carbs": "80 g", "protein": "15 g", "fat": "5 g",
        "allergy_info": "밀(면), 고추장", "info": "나트륨/탄수화물 높음 (시원한 별미)",
    },
    "돈파육덮밥": {
        "calorie": "650 kcal", "carbs": "85 g", "protein": "35 g", "fat": "20 g",
        "allergy_info": "돼지고기, 대두(소스)", "info": "고칼로리, 중식 덮밥",
    },
    "홍합진짬뽕": {
        "calorie": "480 kcal", "carbs": "60 g", "protein": "30 g", "fat": "15 g",
        "allergy_info": "밀(면), 홍합(조개류)", "info": "해산물/나트륨 주의",
    },
    "찹쌀밥": {
        "calorie": "240 kcal", "carbs": "50 g", "protein": "5 g", "fat": "2 g",
        "allergy_info": "없음", "info": "주식 (일반 밥과 유사)",
    },
    "새우볶음밥": {
        "calorie": "490 kcal", "carbs": "75 g", "protein": "18 g", "fat": "12 g",
        "allergy_info": "새우, 계란", "info": "새우 알레르기 주의",
    },
    "버섯불고기": {
        "calorie": "380 kcal", "carbs": "15 g", "protein": "40 g", "fat": "18 g",
        "allergy_info": "쇠고기, 대두", "info": "버섯 포함 고단백",
    },
    "수육백반": {
        "calorie": "700 kcal", "carbs": "60 g", "protein": "50 g", "fat": "30 g",
        "allergy_info": "돼지고기", "info": "고단백, 지방 적당",
    },
    "우동": {
        "calorie": "350 kcal", "carbs": "65 g", "protein": "15 g", "fat": "4 g",
        "allergy_info": "밀(면)", "info": "나트륨/탄수화물 주의",
    },
    "차돌박이": {
        "calorie": "600 kcal", "carbs": "5 g", "protein": "25 g", "fat": "55 g",
        "allergy_info": "쇠고기", "info": "매우 고지방 (구이 기준)",
    },
    # 추가 메뉴 (이미지 & 야채비빔고기튀김)
    "야채비빔고기튀김": {
        "calorie": "680 kcal", "carbs": "70 g", "protein": "35 g", "fat": "30 g",
        "allergy_info": "밀(튀김옷), 돼지고기/쇠고기(고기)", "info": "고칼로리, 고지방 (가정치)",
    },
    "돼사태찜": {
        "calorie": "450 kcal", "carbs": "25 g", "protein": "40 g", "fat": "25 g",
        "allergy_info": "돼지고기, 대두", "info": "돈사태찜과 동일한 정보",
    },
    "해물볶음짬뽕밥": {
        "calorie": "650 kcal", "carbs": "80 g", "protein": "30 g", "fat": "25 g",
        "allergy_info": "밀, 해산물(오징어, 새우)", "info": "중식, 고칼로리",
    },
    "해물볶음우동": {
        "calorie": "550 kcal", "carbs": "70 g", "protein": "25 g", "fat": "20 g",
        "allergy_info": "밀(면), 해산물", "info": "중식, 나트륨 주의",
    },
    "팽이장국": {
        "calorie": "50 kcal", "carbs": "8 g", "protein": "2 g", "fat": "1 g",
        "allergy_info": "대두", "info": "저칼로리 국",
    },
    "치킨마요덮밥": {
        "calorie": "720 kcal", "carbs": "85 g", "protein": "35 g", "fat": "30 g",
        "allergy_info": "닭고기, 밀, 계란", "info": "마요네즈로 인한 고지방",
    },
    "퐁리조또": {
        "calorie": "480 kcal", "carbs": "55 g", "protein": "20 g", "fat": "20 g",
        "allergy_info": "유제품(치즈)", "info": "양식, 퓨전 덮밥",
    },
    "치즈돈카츠샌드위치": {
        "calorie": "450 kcal", "carbs": "40 g", "protein": "25 g", "fat": "20 g",
        "allergy_info": "밀, 계란, 유제품, 돼지고기", "info": "고지방 샌드위치",
    },
}

# --- 1-2. 국/찌개류 (Soup/Stew)
SOUP_STEW_DB = {
    # 기존 메뉴
    "닭곰탕": {
        "calorie": "177 kcal", "carbs": "7 g", "protein": "26.3 g", "fat": "5 g",
        "allergy": "닭고기", "info": "단백질 풍부, 국물 나트륨 주의",
    },
    "두부된장국": {
        "calorie": "50 kcal", "carbs": "5 g", "protein": "4 g", "fat": "2 g",
        "allergy": "대두", "info": "두부(대두) 알레르기 주의",
    },
    "쇠고기무국": {
        "calorie": "123 kcal", "carbs": "7.8 g", "protein": "14.2 g", "fat": "4 g",
        "allergy_info": "쇠고기", "info": "저칼로리 국",
    },
    "순두부찌개": {
        "calorie": "150 kcal", "carbs": "10 g", "protein": "10 g", "fat": "7 g",
        "allergy_info": "대두(두부)", "info": "저칼로리 찌개",
    },
    "맑은순두부찌개": {
        "calorie": "100 kcal", "carbs": "7 g", "protein": "10 g", "fat": "4 g",
        "allergy_info": "대두(두부)", "info": "저칼로리 국물",
    },
    "사골순대국": {
        "calorie": "550 kcal", "carbs": "60 g", "protein": "30 g", "fat": "20 g",
        "allergy_info": "돼지고기, 대두(순대)", "info": "고지방 국물 주의",
    },
    "참치김치찌개": {
        "calorie": "280 kcal", "carbs": "20 g", "protein": "25 g", "fat": "12 g",
        "allergy_info": "생선(참치), 대두", "info": "단백질 풍부, 나트륨 주의",
    },
    "돈육김치찌개": {
        "calorie": "320 kcal", "carbs": "25 g", "protein": "30 g", "fat": "15 g",
        "allergy_info": "돼지고기, 대두", "info": "단백질/지방 함량 높음",
    },
    "설렁탕": {
        "calorie": "400 kcal", "carbs": "5 g", "protein": "30 g", "fat": "28 g",
        "allergy_info": "쇠고기", "info": "고지방 국물 주의",
    },
    # 추가 메뉴 (이미지)
    "두부버섯된장국": {
        "calorie": "80 kcal", "carbs": "8 g", "protein": "5 g", "fat": "3 g",
        "allergy_info": "대두", "info": "된장 베이스, 저칼로리",
    },
    "연두부계란찜": {
        "calorie": "90 kcal", "carbs": "5 g", "protein": "6 g", "fat": "5 g",
        "allergy_info": "계란, 대두", "info": "애호박계란찜과 유사",
    },
}

# --- 1-3. 반찬/사이드 메뉴 (Side Dishes/Appetizers)
SIDE_DISHES_DB = {
    # 기존 메뉴
    "단무지": {
        "calorie": "3 kcal", "carbs": "0.8 g", "protein": "0.1 g", "fat": "0 g",
        "allergy": "없음", "info": "나트륨 주의",
    },
    "배추김치": {
        "calorie": "10 kcal", "carbs": "2 g", "protein": "1 g", "fat": "0 g",
        "allergy": "새우젓(갑각류)", "info": "저칼로리 반찬",
    },
    "단호박튀김": {
        "calorie": "150 kcal", "carbs": "20 g", "protein": "2 g", "fat": "7 g",
        "allergy_info": "밀", "info": "튀김류",
    },
    "오징어젓갈채": {
        "calorie": "100 kcal", "carbs": "15 g", "protein": "5 g", "fat": "3 g",
        "allergy_info": "오징어, 갑각류", "info": "나트륨 높음",
    },
    "참나물무침": {
        "calorie": "25 kcal", "carbs": "5 g", "protein": "1 g", "fat": "0 g",
        "allergy_info": "없음", "info": "신선 채소",
    },
    "깍두기": {
        "calorie": "15 kcal", "carbs": "3 g", "protein": "1 g", "fat": "0 g",
        "allergy_info": "새우젓(갑각류)", "info": "저칼로리 반찬",
    },
    "브로콜리숙회": {
        "calorie": "50 kcal", "carbs": "8 g", "protein": "4 g", "fat": "0 g",
        "allergy_info": "없음", "info": "비타민 C 풍부",
    },
    "예리알곤약조림": {
        "calorie": "120 kcal", "carbs": "25 g", "protein": "5 g", "fat": "0 g",
        "allergy_info": "없음", "info": "저칼로리 반찬",
    },
    "애호박계란찜": {
        "calorie": "90 kcal", "carbs": "5 g", "protein": "6 g", "fat": "5 g",
        "allergy_info": "계란", "info": "부드러운 단백질 공급",
    },
    "콥샐러드": {
        "calorie": "350 kcal", "carbs": "15 g", "protein": "25 g", "fat": "20 g",
        "allergy_info": "계란, 유제품, 견과류(드레싱)", "info": "채소/단백질 균형식",
    },
    "숙성볶음": {
        "calorie": "350 kcal", "carbs": "10 g", "protein": "40 g", "fat": "18 g",
        "allergy_info": "돼지고기(추정)", "info": "고단백 반찬",
    },
    "고추장아찌무침": {
        "calorie": "40 kcal", "carbs": "8 g", "protein": "1 g", "fat": "0 g",
        "allergy_info": "대두(간장)", "info": "저칼로리, 나트륨 약간 높음",
    },
    "감자채근대볶음": {
        "calorie": "80 kcal", "carbs": "10 g", "protein": "2 g", "fat": "4 g",
        "allergy_info": "없음", "info": "식이섬유 포함",
    },
    "단호박식혜": {
        "calorie": "180 kcal", "carbs": "45 g", "protein": "1 g", "fat": "0 g",
        "allergy_info": "없음", "info": "고당류 후식",
    },
    "떡갈비": {
        "calorie": "220 kcal", "carbs": "15 g", "protein": "15 g", "fat": "12 g",
        "allergy_info": "쇠고기, 돼지고기, 대두", "info": "주요 단백질 반찬",
    },
    "오징어채볶음": {
        "calorie": "100 kcal", "carbs": "15 g", "protein": "5 g", "fat": "3 g",
        "allergy_info": "오징어", "info": "나트륨 주의",
    },
    "파닭파채": {
        "calorie": "300 kcal", "carbs": "15 g", "protein": "35 g", "fat": "12 g",
        "allergy_info": "닭고기, 밀(튀김옷)", "info": "튀김옷 포함 단백질 반찬",
    },
    "가자미순살튀김": {
        "calorie": "250 kcal", "carbs": "15 g", "protein": "20 g", "fat": "12 g",
        "allergy_info": "밀(튀김옷), 생선(가자미)", "info": "튀김류",
    },
    "미니돈까스": {
        "calorie": "350 kcal", "carbs": "25 g", "protein": "20 g", "fat": "20 g",
        "allergy_info": "돼지고기, 밀, 계란", "info": "튀김류, 고지방",
    },
    "잡채": {
        "calorie": "200 kcal", "carbs": "30 g", "protein": "10 g", "fat": "5 g",
        "allergy_info": "당면(밀/고구마전분), 대두(간장)", "info": "잔치 음식",
    },
    "핫도그": {
        "calorie": "300 kcal", "carbs": "35 g", "protein": "8 g", "fat": "15 g",
        "allergy_info": "밀, 계란, 유제품", "info": "간식류",
    },
    # 추가 메뉴 (이미지)
    "고슬고슬계란볶음밥": {
        "calorie": "400 kcal", "carbs": "60 g", "protein": "15 g", "fat": "12 g",
        "allergy_info": "계란, 대두", "info": "간단 볶음밥",
    },
    "옥수수야채죽": {
        "calorie": "250 kcal", "carbs": "40 g", "protein": "10 g", "fat": "6 g",
        "allergy_info": "없음", "info": "소고기야채죽과 유사",
    },
    "다시마부각채": {
        "calorie": "150 kcal", "carbs": "20 g", "protein": "3 g", "fat": "7 g",
        "allergy_info": "없음", "info": "튀김류, 칼슘 풍부",
    },
    "가자미순살볶음": {
        "calorie": "180 kcal", "carbs": "10 g", "protein": "20 g", "fat": "7 g",
        "allergy_info": "생선(가자미)", "info": "저지방 단백질",
    },
    "고들빼기무침": {
        "calorie": "30 kcal", "carbs": "5 g", "protein": "1 g", "fat": "0 g",
        "allergy_info": "없음", "info": "나물, 저칼로리",
    },
    "단무지채무침": {
        "calorie": "20 kcal", "carbs": "4 g", "protein": "0 g", "fat": "0 g",
        "allergy_info": "없음", "info": "단무지보다 간이 강함",
    },
    "쫄깃가루탕수": {
        "calorie": "380 kcal", "carbs": "40 g", "protein": "20 g", "fat": "15 g",
        "allergy_info": "밀, 돼지고기", "info": "탕수육과 유사",
    },
    "닭봉": {
        "calorie": "320 kcal", "carbs": "10 g", "protein": "30 g", "fat": "18 g",
        "allergy_info": "닭고기", "info": "닭고기 부위",
    },
    "유부초밥": {
        "calorie": "350 kcal", "carbs": "60 g", "protein": "10 g", "fat": "8 g",
        "allergy_info": "대두", "info": "간편 메뉴",
    },
    "허브치즈닭갈비": {
        "calorie": "480 kcal", "carbs": "20 g", "protein": "40 g", "fat": "25 g",
        "allergy_info": "닭고기, 유제품(치즈)", "info": "고단백, 치즈 추가",
    },
    "미니닭갈비덮밥": {
        "calorie": "350 kcal", "carbs": "40 g", "protein": "25 g", "fat": "10 g",
        "allergy_info": "닭고기", "info": "닭갈비덮밥의 미니 버전",
    },
    "해쉬브라운": {
        "calorie": "180 kcal", "carbs": "20 g", "protein": "2 g", "fat": "10 g",
        "allergy_info": "없음", "info": "감자튀김류",
    },
    "해물모둠전": {
        "calorie": "350 kcal", "carbs": "30 g", "protein": "15 g", "fat": "18 g",
        "allergy_info": "밀, 계란, 해산물", "info": "모둠 해물 전",
    },
    "단무지무침": {
        "calorie": "20 kcal", "carbs": "4 g", "protein": "0 g", "fat": "0 g",
        "allergy_info": "없음", "info": "단무지보다 간이 강함",
    },
    "오징어채볶음": {
        "calorie": "100 kcal", "carbs": "15 g", "protein": "5 g", "fat": "3 g",
        "allergy_info": "오징어", "info": "나트륨 주의",
    },
    "모닝롤": {
        "calorie": "120 kcal", "carbs": "20 g", "protein": "4 g", "fat": "3 g",
        "allergy_info": "밀, 계란, 유제품", "info": "빵류",
    },
    "아몬드멸치볶음": {
        "calorie": "150 kcal", "carbs": "10 g", "protein": "10 g", "fat": "8 g",
        "allergy_info": "견과류(아몬드), 멸치", "info": "칼슘/단백질 풍부",
    },
    "깻잎나물무침": {
        "calorie": "20 kcal", "carbs": "3 g", "protein": "1 g", "fat": "0 g",
        "allergy_info": "없음", "info": "신선 채소",
    },
    "브로콜리숙회": {
        "calorie": "50 kcal", "carbs": "8 g", "protein": "4 g", "fat": "0 g",
        "allergy_info": "없음", "info": "비타민 C 풍부",
    },
    "돈마스터드미트볼": {
        "calorie": "400 kcal", "carbs": "30 g", "protein": "25 g", "fat": "20 g",
        "allergy_info": "돼지고기, 밀, 계란", "info": "육류 반찬",
    },
    "생야채무침": {
        "calorie": "50 kcal", "carbs": "8 g", "protein": "2 g", "fat": "1 g",
        "allergy_info": "없음", "info": "신선 채소",
    },
    "코울슬러": {
        "calorie": "150 kcal", "carbs": "15 g", "protein": "2 g", "fat": "9 g",
        "allergy_info": "유제품(마요네즈)", "info": "양배추 샐러드",
    },
}

# 모든 DB를 하나로 통합하여 검색을 용이하게 합니다.
NUTRITION_MANUAL_DB = {**RICE_MAIN_DB, **SOUP_STEW_DB, **SIDE_DISHES_DB}

def generate_final_response(menu_names_list):
    """
    제공된 메뉴 이름 리스트와 수동 DB를 매칭하여 최종 응답을 구성합니다.
    (크롤링/OCR 로직이 없으므로, 메뉴 리스트를 인자로 직접 받습니다.)
    """

    final_menu = []

    for name in menu_names_list:
        # 1. 수동 DB 매칭
        # 공백/특수문자 제거 후 DB 검색
        cleaned_name_key = name.replace(" ", "").replace("/", "").replace(",", "").strip()

        # DB 검색. 없을 경우 기본 '매칭 데이터 없음' 정보 반환
        nutrition = NUTRITION_MANUAL_DB.get(cleaned_name_key, {
            "calorie": "정보 없음", "protein": "정보 없음", "carbs": "정보 없음", "fat": "정보 없음", "allergy_info": "매칭 데이터 없음", "info": "정보 없음"
        })

        # DB에 있는 "allergy" 키를 "allergy_info"로 통일 (기존 데이터 호환)
        if "allergy" in nutrition:
             nutrition["allergy_info"] = nutrition.pop("allergy")


        final_item = {
            "name": name,
            "price": "5,500", # 가격 정보는 수동으로 추가해야 합니다.
            "nutrition": nutrition
        }
        final_menu.append(final_item)

    final_response = {
        "date": datetime.now().strftime("%Y-%m-%d"),
        "restaurant": "한림대 학생 식당",
        "menu_list": final_menu
    }

    return json.dumps(final_response, indent=4, ensure_ascii=False)

# ==============================================================================
# 테스트 실행
# (실제 메뉴 리스트를 직접 입력하여 테스트합니다.)
# ==============================================================================
if __name__ == "__main__":
    #  테스트를 위해 임의의 메뉴 리스트를 정의합니다. 
    TEST_MENU_LIST = [
        "잡곡밥",
        "닭곰탕",
        "야채비빔고기튀김", # 새로 추가된 메뉴 테스트
        "두부버섯된장국",
        "배추김치",
        "새로운 메뉴 (DB에 없음)"
    ]

    print("\n--- 백엔드 학식 API 로직 테스트 시작 (수동 DB 매칭) ---")
    api_response = generate_final_response(TEST_MENU_LIST)
    print("\n--- 프론트엔드에 전달될 최종 API 응답 (JSON 형식) ---")
    print(api_response)