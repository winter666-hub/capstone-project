import requests
import xml.etree.ElementTree as ET
from urllib.parse import quote

# 공공데이터포털 인증키 (Decoding 키)
# 🚨 본인의 키가 맞는지 다시 한번 확인하세요!
SERVICE_KEY = "6ccb706ec8e1109192f697c4838e4620edb5a8e1af783a2a812633d8294b4da4"

CITY_CODE = "32010"     # 춘천시

# 🚨 [수정됨] 250001275(향교 방면) -> 250001274(반대편: 춘천역/학교앞 방면)
NODE_ID = "250001274"   

def get_realtime_bus_arrival():
    """
    실시간 버스 정보를 조회합니다. (resultCode와 headerCd 모두 처리)
    """
    # URL 인코딩 처리
    base_url = "http://apis.data.go.kr/1613000/ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList"
    
    # requests가 자동으로 인코딩하는 것을 방지하기 위해 URL을 직접 조립
    request_url = f"{base_url}?serviceKey={SERVICE_KEY}&pageNo=1&numOfRows=30&_type=xml&cityCode={CITY_CODE}&nodeId={NODE_ID}"

    try:
        print(f"📡 [Real] 버스 API 요청 시도 (NODE_ID: {NODE_ID})...")
        response = requests.get(request_url)
        
        if response.status_code == 200:
            try:
                root = ET.fromstring(response.content)
                
                # 1. 응답 코드 확인 (headerCd 또는 resultCode 둘 다 확인)
                header_cd = root.findtext(".//headerCd")
                result_code = root.findtext(".//resultCode")
                final_code = header_cd if header_cd else result_code
                
                if final_code != "00":
                    print(f"❌ API 응답 코드 이상: {final_code}")
                    return []

                items = root.findall(".//item")
                print(f"🔎 [Real] 발견된 버스 수: {len(items)}대")
                
                # 버스가 없으면 빈 리스트 반환 (정상 상황)
                if not items:
                    return []

                bus_list = []
                for item in items:
                    routeno = item.findtext("routeno")
                    arrtime = item.findtext("arrtime")
                    stationcnt = item.findtext("arrprevstationcnt")

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
                print("❌ XML 파싱 실패")
                return []
        else:
            print(f"❌ HTTP 요청 실패: {response.status_code}")
            return []

    except Exception as e:
        print(f"❌ 서버 통신 중 오류: {e}")
        return []

if __name__ == "__main__":
    print(get_realtime_bus_arrival())