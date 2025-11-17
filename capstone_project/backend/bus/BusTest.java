
// BusTest.java
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import org.w3c.dom.*;

public class BusTest {

    private static final String SERVICE_KEY = "5a4469982493d91252147da99404ed2e3f2905a5e7ca77f03d55fa557620cf54";
    private static final String CITY_CODE = "32010";     // 춘천 cityCode
    private static final String NODE_ID = "250001275";   // 한림대학교 정류장 nodeId

    public static void main(String[] args) {
        try {
            String urlStr =
                "http://apis.data.go.kr/1613000/ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList"
                + "?serviceKey=" + SERVICE_KEY
                + "&pageNo=1"
                + "&numOfRows=20"
                + "&cityCode=" + CITY_CODE
                + "&nodeId=" + NODE_ID;

            System.out.println("📡 요청 URL:");
            System.out.println(urlStr);

            URL url = new URL(urlStr);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");

            BufferedReader br = new BufferedReader(
                new InputStreamReader(conn.getInputStream(), "UTF-8")
            );

            StringBuilder result = new StringBuilder();
            String line;

            while ((line = br.readLine()) != null) {
                result.append(line);
            }

            br.close();
            conn.disconnect();

            System.out.println("\n📄 원본 XML 응답:");
            System.out.println(result.toString());

            // XML 파싱
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            DocumentBuilder builder = factory.newDocumentBuilder();
            Document doc = builder.parse(new java.io.ByteArrayInputStream(result.toString().getBytes()));

            NodeList items = doc.getElementsByTagName("item");

            System.out.println("\n🚌 도착 예정 버스 목록");

            if (items.getLength() == 0) {
                System.out.println("현재 도착 예정 버스가 없습니다.");
                return;
            }

            for (int i = 0; i < items.getLength(); i++) {
                Element item = (Element) items.item(i);

                String routeno = getTagValue("routeno", item);
                String routetp = getTagValue("routetp", item);
                String arrtime = getTagValue("arrtime", item);
                String stationcnt = getTagValue("arrprevstationcnt", item);

                System.out.println("------------------------------");
                System.out.println("버스 " + (i + 1));
                System.out.println("노선명: " + routeno);
                System.out.println("방향: " + routetp);
                System.out.println("도착 예정시간: " + arrtime + "초 후");
                System.out.println("남은 정거장: " + stationcnt);
            }

        } catch (Exception e) {
            System.out.println("❌ 오류 발생:");
            e.printStackTrace();
        }
    }

    private static String getTagValue(String tag, Element element) {
        NodeList nl = element.getElementsByTagName(tag);
        if (nl.getLength() == 0) return "";
        Node node = nl.item(0).getFirstChild();
        return node != null ? node.getNodeValue() : "";
    }
}
