# backend/bus/bus_api.py

import requests
from bs4 import BeautifulSoup

# 공공데이터포털 인증키 (Java 코드에 있던 키 사용)
# 주의: 실제 배포 시에는 환경변수로 관리하는 것이 좋습니다.
SERVICE_KEY = "5a4469982493d91252147da99404ed2e3f2905a5e7ca77f03d55fa557620cf54"
CITY_CODE = "32010"     # 춘천시
NODE_ID = "250001275"   # 한림대학교 정류장

def get_realtime_bus_arrival():
    """
    한림대학교 정류장의 실시간 버스 도착 정보를 API로 조회하여 리스트로 반환합니다.
    """
    url = "http://apis.data.go.kr/1613000/ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList"
    
    # API 요청 파라미터 설정
    params = {
        "serviceKey": SERVICE_KEY,
        "pageNo": "1",
        "numOfRows": "20",
        "_type": "xml",  # XML 형식 요청 (BeautifulSoup 파싱 용이)
        "cityCode": CITY_CODE,
        "nodeId": NODE_ID
    }

    try:
        # 1. API 요청
        # (서비스 키가 이미 인코딩된 상태라면 decode 필요 없지만, requests는 자동 처리해주는 경우가 많습니다. 
        # 만약 SERVICE_KEY_IS_NOT_REGISTERED_ERROR가 뜨면 키 인코딩 이슈일 수 있습니다.)
        response = requests.get(url, params=params)
        response.raise_for_status() # HTTP 오류 체크

        # 2. XML 파싱
        soup = BeautifulSoup(response.content, "xml")
        
        items = soup.find_all("item")
        bus_list = []

        if not items:
            return [] # 도착 예정 버스 없음

        for item in items:
            # 태그 값 추출 (Java의 getTagValue와 동일)
            routeno = item.find("routeno").text if item.find("routeno") else "정보없음"
            routetp = item.find("routetp").text if item.find("routetp") else "정보없음"
            arrtime = item.find("arrtime").text if item.find("arrtime") else "0"
            stationcnt = item.find("arrprevstationcnt").text if item.find("arrprevstationcnt") else "0"

            # 3. 데이터 구조화 (프론트엔드에서 쓰기 편한 JSON 형태)
            bus_data = {
                "routeNo": routeno,           # 노선 번호 (예: 300)
                "routeType": routetp,         # 노선 타입 (예: 일반)
                "remainingTimeSec": int(arrtime), # 도착 예정 시간 (초)
                "remainingStations": int(stationcnt), # 남은 정류장 수
                "message": f"{int(arrtime)//60}분 {int(arrtime)%60}초 후 도착 ({stationcnt}번째 전)" # 바로 보여줄 메시지
            }
            bus_list.append(bus_data)

        return bus_list

    except Exception as e:
        print(f"버스 API 조회 중 오류 발생: {e}")
        return []

# 테스트 실행 코드
if __name__ == "__main__":
    result = get_realtime_bus_arrival()
    print(f"조회된 버스 목록: {result}")