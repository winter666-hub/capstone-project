import requests
from bs4 import BeautifulSoup
import json
from datetime import datetime

# ==============================================================================
# 1. 학식 메뉴 크롤링 또는 수집 로직 (백엔드 팀의 핵심 작업)
# ==============================================================================
def get_today_menu(date=None):
    """
    특정 날짜의 학교 학식 메뉴 데이터를 가져오는 함수입니다.
    
    Args:
        date (str): YYYY-MM-DD 형식의 날짜 문자열. 기본값은 오늘 날짜입니다.
        
    Returns:
        dict: 메뉴 이름 리스트와 식당 정보를 포함하는 딕셔너리.
    """
    if date is None:
        date = datetime.now().strftime("%Y-%m-%d")
        
    print(f"[{date}] 날짜의 학식 메뉴를 가져오는 중...")
    
    url = "https://example.com/school_cafeteria_menu"  #학식 사이트 주소

    try:
        # 1. 웹페이지 HTML 코드 가져오기
        response = requests.get(url)
        response.raise_for_status() # HTTP 오류가 발생하면 예외 발생

        # 2. BeautifulSoup으로 HTML 파싱
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # 3. 메뉴 정보가 담긴 특정 영역 찾기 (예시: class='menu-list' 태그)
        # 이 부분의 'menu-list'는 학교 웹사이트의 실제 class명으로 대체해야 합니다.
        menu_container = soup.find('div', class_='menu-list') 
        
        menu_list = []
        if menu_container:
            # 4. 메뉴 이름 텍스트만 추출 (예시: <li> 태그 사용)
            for item in menu_container.find_all('li'): 
                menu_name = item.get_text(strip=True)
                menu_list.append({"name": menu_name, "price": 0}) 
        
        if not menu_list:
            print("경고: 크롤링 실패 또는 메뉴 없음. 임시 데이터 사용.")
            
        # 임시 데이터 (크롤링이 실패하거나 없는 경우 사용)
        return {
            "restaurant": "학생 식당 (본관)",
            "menu": [
                {"name": "닭개장", "price": 4500},
                {"name": "제육볶음", "price": 5500},
                {"name": "흰밥", "price": 500},
                {"name": "김치", "price": 0},
            ]
        }

    except requests.exceptions.RequestException as e:
        print(f"웹사이트 접속 오류 발생: {e}. 임시 데이터 사용.")
        return {
            "restaurant": "학생 식당 (본관)",
            "menu": [
                {"name": "닭개장", "price": 4500},
                {"name": "제육볶음", "price": 5500},
                {"name": "흰밥", "price": 500},
                {"name": "김치", "price": 0},
            ]
        }


# ==============================================================================
# 2. 식약처 영양 성분 매칭 및 데이터 관리 
# ==============================================================================
def match_nutrition_info(menu_item):
    """
    메뉴 항목에 대한 영양 성분 정보를 매칭하는 함수입니다.
    이곳에 식약처 API 호출 코드가 들어갑니다.
    """
    menu_name = menu_item["name"]
    # print(f"'{menu_name}'에 대한 영양 성분 정보 매칭 중...")
    
    # [TODO 2]: 여기에 식약처 영양성분 API를 호출하고 응답을 처리하는 로직을 작성하세요.
    # YOUR_API_KEY는 발급받은 실제 키로 대체해야 합니다.
    api_key = "YOUR_API_KEY" 
    
    # 임시 영양 정보 (실제 식약처 API 응답으로 대체 필요)
    nutrition_info = {
        "calories": 0, 
        "protein": 0,
        "carbs": 0,
        "fat": 0,
        "allergy_info": "정보 없음"
    }

    # API 호출 로직이 들어가기 전까지는 임시로 메뉴명에 따라 영양 정보를 매칭
    if "닭개장" in menu_name:
        nutrition_info.update({"calories": 350, "protein": 25, "carbs": 30, "fat": 15, "allergy_info": "닭고기"})
    elif "제육볶음" in menu_name:
        nutrition_info.update({"calories": 520, "protein": 35, "carbs": 40, "fat": 20, "allergy_info": "돼지고기"})
    
    return nutrition_info

# ==============================================================================
# 3. 최종 데이터를 프론트엔드에 전달할 API 응답 구성
# ==============================================================================
def generate_final_response():
    """
    프론트엔드 팀에게 전달할 최종 학식 메뉴 응답을 구성합니다.
    """
    raw_menu = get_today_menu()
    final_menu = []
    
    for item in raw_menu["menu"]:
        # 영양 정보 매칭 함수 호출
        nutrition = match_nutrition_info(item)
        
        # 최종 항목 구성
        final_item = {
            "name": item["name"],
            "price": item["price"],
            "nutrition": nutrition
        }
        final_menu.append(final_item)
        
    # 최종 JSON 응답 생성 (API 서버의 응답 형태를 모방)
    final_response = {
        "date": datetime.now().strftime("%Y-%m-%d"),
        "restaurant": raw_menu["restaurant"],
        "menu_list": final_menu
    }
    
    # JSON 문자열로 변환하여 반환
    return json.dumps(final_response, indent=4, ensure_ascii=False)

# ==============================================================================
# 테스트 실행 (이 부분은 파일 자체를 테스트할 때 사용합니다.)
# ==============================================================================
if __name__ == "__main__":
    print("\n--- 백엔드 학식 API 로직 테스트 시작 ---")
    api_response = generate_final_response()
    print("\n--- 프론트엔드에 전달될 최종 API 응답 (JSON 형식) ---")
    print(api_response)