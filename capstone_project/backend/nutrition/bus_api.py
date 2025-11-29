# backend/bus/bus_api.py

import requests
import xml.etree.ElementTree as ET
from urllib.parse import quote

# 🚨 [여기에 발급받은 Decoding 키를 붙여넣으세요] 🚨
# 예: "aBcDeFgHiJkLmNoP..." (따옴표 유지)
SERVICE_KEY = "6ccb706ec8e1109192f697c4838e4620edb5a8e1af783a2a812633d8294b4da4"

CITY_CODE = "32010"     # 춘천시
NODE_ID = "250001275"   # 한림대학교 정류장

def get_realtime_bus_arrival():
    # 1. URL 생성 (ServiceKey는 인코딩 처리)
    # requests는 params로 보내면 자동으로 인코딩하지만, 공공데이터는 까다로워서
    # 안전하게 Decoding 키를 받아서 직접 인코딩해 URL에 붙입니다.
    
    endpoint = "http://apis.data.go.kr/1613000/ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList"
    
    # 서비스 키를 URL 인코딩 (한 번 더 안전장치)
    encoded_key = quote(SERVICE_KEY) 
    
    # 최종 요청 URL 조립
    request_url = f"{endpoint}?serviceKey={SERVICE_KEY}&pageNo=1&numOfRows=30&_type=xml&cityCode={CITY_CODE}&nodeId={NODE_ID}"

    try:
        print(f"📡 [Real] 버스 API 요청 시도...")
        response = requests.get(request_url)
        print(f"📄 [디버그] 응답 원본: {response.text}")
        if response.status_code == 200:
            try:
                root = ET.fromstring(response.content)
                
                # 결과 코드 확인
                header_cd = root.findtext(".//headerCd")
                if header_cd != "00":
                    print(f"❌ API 오류 코드 반환: {header_cd} (키 문제일 가능성 높음)")
                    return []

                items = root.findall(".//item")
                bus_list = []
                
                print(f"🔎 [Real] 발견된 버스 수: {len(items)}대")

                for item in items:
                    routeno = item.findtext("routeno")
                    arrtime = item.findtext("arrtime")
                    stationcnt = item.findtext("arrprevstationcnt")

                    # 필수 데이터가 없으면 건너뜀
                    if not routeno or not arrtime:
                        continue
                    
                    arr_sec = int(arrtime)
                    min_val = arr_sec // 60
                    sec_val = arr_sec % 60
                    
                    if min_val > 0:
                        time_msg = f"{min_val}분 {sec_val}초 후 도착"
                    else:
                        time_msg = "곧 도착"

                    bus_data = {
                        "routeNo": routeno,
                        "remainingTimeSec": arr_sec,
                        "remainingStations": int(stationcnt),
                        "message": time_msg
                    }
                    bus_list.append(bus_data)
                
                return bus_list

            except ET.ParseError:
                print("❌ XML 파싱 실패 (응답 내용이 XML이 아님)")
                return []
        else:
            print(f"❌ HTTP 요청 실패: {response.status_code}")
            return []

    except Exception as e:
        print(f"❌ 서버 통신 중 오류: {e}")
        return []

if __name__ == "__main__":
    print(get_realtime_bus_arrival())