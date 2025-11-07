# backend/nutrition/nutrition_api.py

import requests
from bs4 import BeautifulSoup
from google.cloud import vision
import io
import json
from datetime import datetime
import os
from google.api_core.exceptions import GoogleAPICallError

# ==============================================================================
# 1. 수동 관리 데이터베이스 (직접 입력 부분)
# [TODO]: 여기에 학교 메뉴와 해당 영양 정보를 직접 입력하고 관리해야 합니다.
# ==============================================================================
NUTRITION_MANUAL_DB = {
    # --- 주요 밥류/메인 메뉴 ---
    "잡곡밥": {
        "calorie": "306 kcal",  # 1인분(210g) 기준
        "carbs": "61.6 g",      # 탄수화물
        "protein": "11.1 g",    # 단백질
        "fat": "1.8 g",         # 지방
        "allergy": "없음",
        "info": "다이어트 추천",
    },
    "흰쌀밥": {
        "calorie": "300 kcal",
        "carbs": "65 g",
        "protein": "6 g",
        "fat": "0.5 g",
        "allergy": "없음",
        "info": "흰쌀밥",
    },
    "제육덮밥": {
        "calorie": "716 kcal",  # 1인분(400g) 기준
        "carbs": "79.9 g",      # 탄수화물
        "protein": "30.9 g",    # 단백질
        "fat": "30.3 g",        # 지방
        "allergy": "돼지고기",
        "info": "나트륨 함량 높음",
    },
    "소불고기": {
        "calorie": "489 kcal",  # 1인분(300g) 기준
        "carbs": "15 g",        # 탄수화물
        "protein": "56.5 g",    # 단백질
        "fat": "20.5 g",        # 지방
        "allergy": "쇠고기",
        "info": "단백질 풍부",
    },
    "닭곰탕": {
        "calorie": "177 kcal",  # 1인분(350g) 기준, 밥 제외
        "carbs": "7 g",
        "protein": "26.3 g",    # 단백질
        "fat": "5 g",
        "allergy": "닭고기",
        "info": "단백질 풍부, 국물 나트륨 주의",
    },
    "잔치국수": {
        "calorie": "599 kcal",  # 1회 제공량(700g) 기준
        "carbs": "118.5 g",
        "protein": "21.1 g",    # (잔치국수 1인분 265 kcal, 탄수화물 48.3g)
        "fat": "4.5 g",
        "allergy": "밀",
        "info": "나트륨 함량 높음 (국물 제외 시 낮아짐)",
    },
    # --- 반찬류 ---
    "단무지": {
        "calorie": "3 kcal",    # 1반찬그릇(30g) 기준
        "carbs": "0.8 g",
        "protein": "0.1 g",
        "fat": "0 g",
        "allergy": "없음",
        "info": "나트륨 주의",
    },
    "배추김치": {
        "calorie": "10 kcal",
        "carbs": "2 g",
        "protein": "1 g",
        "fat": "0 g",
        "allergy": "새우젓(갑각류)",
        "info": "저칼로리 반찬",
    },
    "두부된장국": {
        "calorie": "50 kcal",
        "carbs": "5 g",
        "protein": "4 g",
        "fat": "2 g",
        "allergy": "대두",
        "info": "두부(대두) 알레르기 주의",
    },
    "야채매콤비빔밥": {
        "calorie": "550 kcal",
        "carbs": "90 g",
        "protein": "15 g",
        "fat": "15 g",
        "allergy_info": "고추장, 참기름(대두)",
        "info": "나트륨 주의 (비빔밥 소스)",
    },
    "간장불고기": {
        "calorie": "489 kcal", 
        "carbs": "15 g",
        "protein": "56.5 g",
        "fat": "20.5 g",
        "allergy_info": "쇠고기, 대두(간장)",
        "info": "고단백",
    },
    "돈사태찜": {
        "calorie": "450 kcal",
        "carbs": "25 g",
        "protein": "40 g",
        "fat": "25 g",
        "allergy_info": "돼지고기, 대두",
        "info": "단백질/지방 함량 높음",
    },
    "오븐불고기": {
        "calorie": "380 kcal", 
        "carbs": "15 g",
        "protein": "40 g",
        "fat": "18 g",
        "allergy_info": "쇠고기",
        "info": "저지방 불고기",
    },
    "쇠고기무국": {
        "calorie": "123 kcal", 
        "carbs": "7.8 g",
        "protein": "14.2 g",
        "fat": "4 g",
        "allergy_info": "쇠고기",
        "info": "저칼로리 국",
    },
    "떡볶이": {
        "calorie": "400 kcal",
        "carbs": "75 g",
        "protein": "10 g",
        "fat": "5 g",
        "allergy_info": "밀(떡), 고추장",
        "info": "탄수화물 높음 (분식)",
    },
    "마파두부덮밥": {
        "calorie": "600 kcal",
        "carbs": "80 g",
        "protein": "25 g",
        "fat": "18 g",
        "allergy_info": "대두(두부), 밀",
        "info": "두부로 단백질 보충",
    },

    # --- 반찬 및 사이드 메뉴 ---
    "단호박튀김": {
        "calorie": "150 kcal",
        "carbs": "20 g",
        "protein": "2 g",
        "fat": "7 g",
        "allergy_info": "밀",
        "info": "튀김류",
    },
    "오징어젓갈채": {
        "calorie": "100 kcal",
        "carbs": "15 g",
        "protein": "5 g",
        "fat": "3 g",
        "allergy_info": "오징어, 갑각류",
        "info": "나트륨 높음",
    },
    "순두부찌개": {
        "calorie": "150 kcal",
        "carbs": "10 g",
        "protein": "10 g",
        "fat": "7 g",
        "allergy_info": "대두(두부)",
        "info": "저칼로리 찌개",
    },
    "참나물무침": {
        "calorie": "25 kcal",
        "carbs": "5 g",
        "protein": "1 g",
        "fat": "0 g",
        "allergy_info": "없음",
        "info": "신선 채소",
    },
    "배추김치": {
        "calorie": "10 kcal",
        "carbs": "2 g",
        "protein": "1 g",
        "fat": "0 g",
        "allergy_info": "새우젓(갑각류)",
        "info": "저칼로리 반찬",
    },
    "깍두기": {
        "calorie": "15 kcal",
        "carbs": "3 g",
        "protein": "1 g",
        "fat": "0 g",
        "allergy_info": "새우젓(갑각류)",
        "info": "저칼로리 반찬",
    },
    "꽁치김치조림": {  # 11/3 ~ 11/7
        "calorie": "380 kcal",
        "carbs": "30 g",
        "protein": "35 g",
        "fat": "15 g",
        "allergy_info": "꽁치(어류), 대두",
        "info": "단백질 풍부, 나트륨 주의",
    },
    "맑은순두부찌개": {
        "calorie": "100 kcal",
        "carbs": "7 g",
        "protein": "10 g",
        "fat": "4 g",
        "allergy_info": "대두(두부)",
        "info": "저칼로리 국물",
    },
    "브로콜리숙회": {
        "calorie": "50 kcal",
        "carbs": "8 g",
        "protein": "4 g",
        "fat": "0 g",
        "allergy_info": "없음",
        "info": "비타민 C 풍부",
    },
    "소고기야채죽": {
        "calorie": "280 kcal",
        "carbs": "45 g",
        "protein": "15 g",
        "fat": "5 g",
        "allergy_info": "쇠고기",
        "info": "부담 없는 아침 식사",
    },
    "예리알곤약조림": {
        "calorie": "120 kcal",
        "carbs": "25 g",
        "protein": "5 g",
        "fat": "0 g",
        "allergy_info": "없음",
        "info": "저칼로리 반찬",
    },
    "애호박계란찜": {
        "calorie": "90 kcal",
        "carbs": "5 g",
        "protein": "6 g",
        "fat": "5 g",
        "allergy_info": "계란",
        "info": "부드러운 단백질 공급",
    },
    "잡볶음밥": {
        "calorie": "450 kcal",
        "carbs": "70 g",
        "protein": "15 g",
        "fat": "12 g",
        "allergy_info": "대두",
        "info": "혼합 채소 포함",
    },
    "해물볶음밥": {
        "calorie": "490 kcal",
        "carbs": "75 g",
        "protein": "18 g",
        "fat": "12 g",
        "allergy_info": "새우, 오징어",
        "info": "해산물 알레르기 주의",
    },
    "잡채밥": {
        "calorie": "650 kcal",
        "carbs": "95 g",
        "protein": "20 g",
        "fat": "20 g",
        "allergy_info": "밀, 돼지고기",
        "info": "탄수화물 함량 높음",
    },
    "사골순대국": {
        "calorie": "550 kcal",
        "carbs": "60 g",
        "protein": "30 g",
        "fat": "20 g",
        "allergy_info": "돼지고기, 대두(순대)",
        "info": "고지방 국물 주의",
    },
    "참치김치찌개": {
        "calorie": "280 kcal",
        "carbs": "20 g",
        "protein": "25 g",
        "fat": "12 g",
        "allergy_info": "생선(참치), 대두",
        "info": "단백질 풍부, 나트륨 주의",
    },
    "돈육김치찌개": {
        "calorie": "320 kcal",
        "carbs": "25 g",
        "protein": "30 g",
        "fat": "15 g",
        "allergy_info": "돼지고기, 대두",
        "info": "단백질/지방 함량 높음",
    },
    "제육김치볶음밥": {
        "calorie": "680 kcal",
        "carbs": "85 g",
        "protein": "30 g",
        "fat": "25 g",
        "allergy_info": "돼지고기",
        "info": "나트륨/지방 함량 높음",
    },
    
    "콥샐러드": {
        "calorie": "350 kcal",
        "carbs": "15 g",
        "protein": "25 g",
        "fat": "20 g",
        "allergy_info": "계란, 유제품, 견과류(드레싱)",
        "info": "채소/단백질 균형식",
    },
    "눈꽃치즈닭갈비덮밥": {
        "calorie": "780 kcal",
        "carbs": "90 g",
        "protein": "45 g",
        "fat": "30 g",
        "allergy_info": "닭고기, 유제품(치즈)",
        "info": "고칼로리 메인 메뉴",
    },
}
    
    # --- 기타 메뉴 (필요 시 계속 추가) ---
    # ...


# ==============================================================================
# 2. 크롤링 및 OCR 연동 함수
# ==============================================================================

def get_latest_menu_detail_url():
    """ 공지사항 목록에서 가장 최근의 '한림대 학생식당 메뉴게시' 링크를 찾습니다. """
    NOTICE_LIST_URL = "https://dorm.ourhome.co.kr/notice.aspx"
    BASE_URL = "https://dorm.ourhome.co.kr/" 

    try:
        response = requests.get(NOTICE_LIST_URL)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, 'html.parser')

        # [최종 수정]: "board_list" 클래스를 가진 DIV 태그를 찾습니다.
        board_area = soup.find('div', class_='board_list') 
        
        if not board_area: 
            # 만약 div board_list를 못 찾을 경우, 아래 메시지가 출력됩니다.
            print("경고: 상위 목록 컨테이너(div class='board_list')를 찾지 못했습니다.")
            return None

        # 테이블 안의 모든 링크('a' 태그)를 찾습니다.
        links = board_area.find_all('a') 
        
        for link in links:
            title = link.get_text(strip=True)
            href = link.get('href')

            if "한림대 학생식당 메뉴게시" in title and "seq=" in href:
                if href.startswith('http'):
                    return href
                else:
                    return f"{BASE_URL}{href}"

        print("경고: '한림대 학생식당 메뉴게시' 링크를 찾지 못했습니다.")
        return None

    except requests.exceptions.RequestException as e:
        print(f"목록 페이지 접속 오류 발생: {e}")
        return None

    except requests.exceptions.RequestException as e:
        print(f"목록 페이지 접속 오류 발생: {e}")
        return None


def get_menu_image_url(detail_page_url):
    """ 2차 크롤링: 상세 페이지에서 메뉴 이미지의 URL을 추출합니다. """
    try:
        response = requests.get(detail_page_url)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # [주의]: 이미지 태그의 src 속성을 정확히 찾아야 합니다.
        # 공지사항 본문 내용이 들어있는 영역을 찾은 후 그 안의 <img> 태그를 찾습니다.
        # 이 부분의 클래스명은 실제 웹사이트 구조에 따라 달라질 수 있습니다.
        image_tag = soup.find('td', {'class': 'bbs_txt'}).find('img')
        
        if image_tag and image_tag.get('src'):
            return image_tag.get('src')
        return None

    except Exception as e:
        print(f"이미지 URL 추출 오류 발생: {e}")
        return None


def download_menu_image(image_url, save_path="temp_menu.jpg"):
    """ 메뉴 이미지를 다운로드하여 로컬에 저장합니다. """
    try:
        response = requests.get(image_url, stream=True)
        response.raise_for_status()
            
        with open(save_path, 'wb') as file:
            for chunk in response.iter_content(chunk_size=8192):
                file.write(chunk)
        return save_path
            
    except requests.exceptions.RequestException as e:
        print(f"이미지 다운로드 오류 발생: {e}")
        return None


def detect_text_from_image(image_path):
    """ Google Cloud Vision API를 사용하여 이미지에서 텍스트를 추출하고, 임시 파일을 삭제합니다. """
    
    try:
        client = vision.ImageAnnotatorClient()
        with io.open(image_path, 'rb') as image_file:
            content = image_file.read()

        image = vision.Image(content=content)
        response = client.text_detection(image=image)
        
        if response.text_annotations:
            # 이미지 전체의 텍스트 반환
            return response.text_annotations[0].description
        return ""
    
    except GoogleAPICallError as e:
        print(f"Vision API 호출 오류 발생 (인증 문제): {e}")
        return None
        
    finally:
        # 사용 후 임시 파일 삭제
        if os.path.exists(image_path):
            os.remove(image_path)


def clean_ocr_text_to_menu_list(full_text):
    """ OCR 추출 텍스트를 파싱하여 메뉴 이름 리스트를 만듭니다. """
    menu_names = []
    lines = full_text.split('\n')
    
    for line in lines:
        if "요일:" in line:
            parts = line.split(':')
            if len(parts) > 1:
                # '닭곰탕, 잡채, 깍두기'와 같은 부분만 가져옵니다.
                menu_items_raw = parts[1].strip()
                # 쉼표, 슬래시 등을 기준으로 메뉴를 분리하고 불필요한 공백을 제거합니다.
                items = [item.strip() for item in menu_items_raw.replace('/', ',').split(',') if item.strip()]
                
                for item in items:
                    # 너무 짧거나 불필요한 텍스트 필터링 (ex: 띄어쓰기, 괄호 제거)
                    clean_item = item.replace('(', '').replace(')', '').replace('.', '').strip()
                    if len(clean_item) > 1 and not any(keyword in clean_item for keyword in ["식단", "아침", "점심", "저녁"]):
                        menu_names.append(clean_item)
                        
    return menu_names


# ==============================================================================
# 3. 최종 API 응답 구성
# ==============================================================================
def generate_final_response():
    """ 최종 학식 메뉴 응답 구성 (OCR 텍스트 기반 및 수동 DB 매칭) """
    
    # 1. 1차 크롤링: 최신 상세 페이지 URL 가져오기
    detail_page_url = get_latest_menu_detail_url()
    if not detail_page_url:
        return json.dumps({"error": "메뉴 상세 페이지 링크를 찾을 수 없음"}, indent=4, ensure_ascii=False)
    
    # 2. 2차 크롤링: 이미지 URL 가져오기
    IMAGE_URL = "https://dorm.ourhome.co.kr/image/notice/2fca66b5-288b-4f8a-873a-4b8045076143.jpg"

    # 3. 이미지 다운로드 및 OCR 분석
    temp_file_path = download_menu_image(IMAGE_URL)
    if not temp_file_path:
        return json.dumps({"error": "이미지 다운로드 실패"}, indent=4, ensure_ascii=False)

    full_ocr_text = detect_text_from_image(temp_file_path)
    if not full_ocr_text:
        return json.dumps({"error": "OCR 텍스트 추출 실패"}, indent=4, ensure_ascii=False)
    
    # 4. 메뉴 이름 클리닝
    menu_names_from_ocr = clean_ocr_text_to_menu_list(full_ocr_text)
    
    final_menu = []
    
    for name in menu_names_from_ocr:
        # 5. 수동 DB 매칭
        # 공백 제거 후 DB 검색 (ex: "제육덮밥" == "제육 덮밥" 방지)
        cleaned_name_key = name.replace(" ", "")
        
        nutrition = NUTRITION_MANUAL_DB.get(cleaned_name_key, {
            "calories": 0, "protein": 0, "carbs": 0, "fat": 0, "allergy_info": "매칭 데이터 없음"
        })
        
        final_item = {
            "name": name,
            "price": 0, # 가격 정보 필요
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
# ==============================================================================
if __name__ == "__main__":
    print("\n--- 백엔드 학식 API 로직 테스트 시작 ---")
    api_response = generate_final_response()
    print("\n--- 프론트엔드에 전달될 최종 API 응답 (JSON 형식) ---")
    print(api_response)

# nutrition_api.py 파일 가장 아래쪽에 추가

if __name__ == "__main__":
    print("\n--- 1차 크롤링 테스트 시작 ---")
    
    # get_latest_menu_detail_url 함수를 호출하고 결과를 변수에 저장
    test_url = get_latest_menu_detail_url()
    
    if test_url:
        print(f"✅ 성공: 최신 메뉴 상세 URL을 찾았습니다.")
        print(f"   추출된 URL: {test_url}")
        
        # 추가 확인: 찾은 URL이 실제 공지사항 링크 형태인지 확인
        if "noticeView.aspx" in test_url and "seq=" in test_url:
            print("   (URL 형식 검사 통과)")
        else:
            print("   ❌ 오류: URL 형식이 예상과 다릅니다. 크롤링 로직을 다시 확인하세요.")
            
    else:
        print("❌ 실패: 최신 메뉴 상세 URL을 찾지 못했습니다. 크롤링 코드를 확인하세요.")