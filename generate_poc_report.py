#!/usr/bin/env python3
"""Generate Paylisher PoC SDK Capability Assessment PDF Report."""

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm, cm
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_RIGHT
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, HRFlowable, KeepTogether
)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from datetime import datetime
import os

# Colors
PAYLISHER_BLUE = colors.HexColor("#1a73e8")
PAYLISHER_DARK = colors.HexColor("#1a1a2e")
HEADER_BG = colors.HexColor("#1a73e8")
SUCCESS_GREEN = colors.HexColor("#0d904f")
PARTIAL_ORANGE = colors.HexColor("#e67e22")
BACKEND_BLUE = colors.HexColor("#3498db")
NOT_AVAILABLE = colors.HexColor("#c0392b")
IN_PROGRESS_PURPLE = colors.HexColor("#8e44ad")
LIGHT_GRAY = colors.HexColor("#f5f5f5")
TABLE_HEADER_BG = colors.HexColor("#2c3e50")
ROW_ALT = colors.HexColor("#f8f9fa")

def build_pdf():
    output_path = os.path.join(os.path.dirname(__file__), "Paylisher_PoC_SDK_Degerlendirme.pdf")

    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        rightMargin=18*mm,
        leftMargin=18*mm,
        topMargin=20*mm,
        bottomMargin=20*mm,
    )

    styles = getSampleStyleSheet()

    # Custom styles
    styles.add(ParagraphStyle(
        name='CoverTitle',
        fontSize=28,
        leading=34,
        textColor=PAYLISHER_DARK,
        alignment=TA_CENTER,
        spaceAfter=8,
        fontName='Helvetica-Bold',
    ))
    styles.add(ParagraphStyle(
        name='CoverSubtitle',
        fontSize=14,
        leading=18,
        textColor=colors.HexColor("#555555"),
        alignment=TA_CENTER,
        spaceAfter=4,
        fontName='Helvetica',
    ))
    styles.add(ParagraphStyle(
        name='SectionTitle',
        fontSize=16,
        leading=20,
        textColor=PAYLISHER_BLUE,
        spaceBefore=16,
        spaceAfter=8,
        fontName='Helvetica-Bold',
    ))
    styles.add(ParagraphStyle(
        name='SubSection',
        fontSize=12,
        leading=16,
        textColor=PAYLISHER_DARK,
        spaceBefore=10,
        spaceAfter=6,
        fontName='Helvetica-Bold',
    ))
    styles.add(ParagraphStyle(
        name='BodyText2',
        fontSize=9,
        leading=13,
        textColor=colors.HexColor("#333333"),
        spaceAfter=4,
        fontName='Helvetica',
    ))
    styles.add(ParagraphStyle(
        name='SmallNote',
        fontSize=8,
        leading=11,
        textColor=colors.HexColor("#777777"),
        spaceAfter=2,
        fontName='Helvetica-Oblique',
    ))
    styles.add(ParagraphStyle(
        name='TableCell',
        fontSize=8,
        leading=11,
        textColor=colors.HexColor("#333333"),
        fontName='Helvetica',
    ))
    styles.add(ParagraphStyle(
        name='TableHeader',
        fontSize=8,
        leading=11,
        textColor=colors.white,
        fontName='Helvetica-Bold',
    ))
    styles.add(ParagraphStyle(
        name='StatusGreen',
        fontSize=8,
        leading=11,
        textColor=SUCCESS_GREEN,
        fontName='Helvetica-Bold',
    ))
    styles.add(ParagraphStyle(
        name='StatusOrange',
        fontSize=8,
        leading=11,
        textColor=PARTIAL_ORANGE,
        fontName='Helvetica-Bold',
    ))
    styles.add(ParagraphStyle(
        name='StatusBlue',
        fontSize=8,
        leading=11,
        textColor=BACKEND_BLUE,
        fontName='Helvetica-Bold',
    ))
    styles.add(ParagraphStyle(
        name='StatusRed',
        fontSize=8,
        leading=11,
        textColor=NOT_AVAILABLE,
        fontName='Helvetica-Bold',
    ))
    styles.add(ParagraphStyle(
        name='StatusPurple',
        fontSize=8,
        leading=11,
        textColor=IN_PROGRESS_PURPLE,
        fontName='Helvetica-Bold',
    ))

    elements = []

    # === COVER PAGE ===
    elements.append(Spacer(1, 60*mm))
    elements.append(Paragraph("PAYLISHER iOS SDK", styles['CoverTitle']))
    elements.append(Spacer(1, 4*mm))
    elements.append(Paragraph("PoC Yetenek Degerlendirme Raporu", styles['CoverSubtitle']))
    elements.append(Spacer(1, 10*mm))
    elements.append(HRFlowable(width="60%", thickness=2, color=PAYLISHER_BLUE, spaceAfter=10, spaceBefore=10))
    elements.append(Spacer(1, 6*mm))
    elements.append(Paragraph(f"SDK Versiyon: 1.6.0", styles['CoverSubtitle']))
    elements.append(Paragraph(f"Platform: iOS 13+, macOS, tvOS, watchOS", styles['CoverSubtitle']))
    elements.append(Paragraph(f"Tarih: {datetime.now().strftime('%d.%m.%Y')}", styles['CoverSubtitle']))
    elements.append(Spacer(1, 8*mm))
    elements.append(Paragraph("Gizli - Sirket Ici Kullanim", styles['SmallNote']))
    elements.append(PageBreak())

    # === SUMMARY SECTION ===
    elements.append(Paragraph("1. Yonetici Ozeti", styles['SectionTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=PAYLISHER_BLUE, spaceAfter=8))
    elements.append(Paragraph(
        "Bu rapor, Paylisher iOS SDK'nin (v1.6.0) PoC gereksinimlerine karsi yetenek degerlendirmesini icerir. "
        "SDK kaynak kodu detayli incelenmis ve her madde icin kod bazinda teyit yapilmistir.",
        styles['BodyText2']
    ))
    elements.append(Spacer(1, 4*mm))

    # Score summary table
    score_data = [
        [Paragraph("Kategori", styles['TableHeader']),
         Paragraph("Sayi", styles['TableHeader']),
         Paragraph("Aciklama", styles['TableHeader'])],
        [Paragraph("SAGLANIYOR", styles['StatusGreen']),
         Paragraph("12", styles['TableCell']),
         Paragraph("SDK'da tam olarak implemente edilmis", styles['TableCell'])],
        [Paragraph("GELISTIRILIYOR", styles['StatusPurple']),
         Paragraph("1", styles['TableCell']),
         Paragraph("SDK'da aktif olarak gelistirme asamasinda", styles['TableCell'])],
        [Paragraph("KISMEN", styles['StatusOrange']),
         Paragraph("10", styles['TableCell']),
         Paragraph("SDK destekliyor ancak uygulama veya backend takviyesi gerekli", styles['TableCell'])],
        [Paragraph("BACKEND", styles['StatusBlue']),
         Paragraph("6", styles['TableCell']),
         Paragraph("SDK kapsaminda degil, backend/dashboard tarafindan saglanmali", styles['TableCell'])],
        [Paragraph("SAGLANMIYOR", styles['StatusRed']),
         Paragraph("4", styles['TableCell']),
         Paragraph("SDK'da mevcut degil, gelistirme gerekli", styles['TableCell'])],
    ]
    score_table = Table(score_data, colWidths=[80, 40, 350])
    score_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), TABLE_HEADER_BG),
        ('BACKGROUND', (0, 1), (-1, 1), ROW_ALT),
        ('BACKGROUND', (0, 3), (-1, 3), ROW_ALT),
        ('BACKGROUND', (0, 5), (-1, 5), ROW_ALT),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#dddddd")),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
    ]))
    elements.append(score_table)
    elements.append(Spacer(1, 8*mm))

    # === DETAILED ASSESSMENT SECTIONS ===

    def status_cell(status):
        mapping = {
            "SAGLANIYOR": ('StatusGreen', "SAGLANIYOR"),
            "KISMEN": ('StatusOrange', "KISMEN"),
            "BACKEND": ('StatusBlue', "BACKEND"),
            "SAGLANMIYOR": ('StatusRed', "SAGLANMIYOR"),
            "GELISTIRILIYOR": ('StatusPurple', "GELISTIRILIYOR"),
        }
        style_name, text = mapping.get(status, ('TableCell', status))
        return Paragraph(text, styles[style_name])

    def make_table(title, rows):
        """Build a themed requirement table with title."""
        elements_out = []
        elements_out.append(Paragraph(title, styles['SubSection']))

        header = [
            Paragraph("Gereksinim", styles['TableHeader']),
            Paragraph("Durum", styles['TableHeader']),
            Paragraph("SDK Detay", styles['TableHeader']),
        ]
        data = [header]
        for req, status, detail in rows:
            data.append([
                Paragraph(req, styles['TableCell']),
                status_cell(status),
                Paragraph(detail, styles['TableCell']),
            ])

        col_widths = [145, 60, 275]
        t = Table(data, colWidths=col_widths, repeatRows=1)
        style_cmds = [
            ('BACKGROUND', (0, 0), (-1, 0), TABLE_HEADER_BG),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#dddddd")),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ('LEFTPADDING', (0, 0), (-1, -1), 5),
            ('RIGHTPADDING', (0, 0), (-1, -1), 5),
        ]
        for i in range(1, len(data)):
            if i % 2 == 0:
                style_cmds.append(('BACKGROUND', (0, i), (-1, i), ROW_ALT))
        t.setStyle(TableStyle(style_cmds))
        elements_out.append(t)
        elements_out.append(Spacer(1, 6*mm))
        return elements_out

    # Section 2 - Segmentasyon & In-App
    elements.append(Paragraph("2. Detayli Degerlendirme", styles['SectionTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=PAYLISHER_BLUE, spaceAfter=8))

    elements.extend(make_table("2.1 Kullanici Segmentasyonu ve In-App Mesajlar", [
        ("Kullanicilarin segment edilmesi ve segmente gore in-app mesaj gosterilmesi",
         "SAGLANIYOR",
         "identify(), group() ve feature flags ile segment bazli in-app mesaj tetikleme. "
         "CustomInAppNotificationManager ile zengin icerik destegi (modal, carousel, fullscreen)."),
        ("App push ve deeplink",
         "SAGLANIYOR",
         "NotificationManager: push ve inApp tipleri tam destekleniyor. "
         "Action-Based bildirimler gelistirme asamasinda. Geofence bildirimler saglanmiyor. "
         "PaylisherDeepLinkManager: URL scheme + Universal Links. "
         "Deferred deep link ile install attribution."),
        ("Uygulamada kullaniciya gore custom ekranlar",
         "SAGLANIYOR",
         "Feature flags + JSON payloads ile kullanici bazli UI kontrolu. "
         "getFeatureFlagPayload() ile dinamik icerik. "
         "Custom in-app layout: text, image, button, buttonGroup, spacer bloklari."),
    ]))

    elements.extend(make_table("2.2 Cihaz ve Kullanici Yonetimi", [
        ("Ayni cihazda birden fazla kullanici login olursa gecmis veri yonetimi",
         "KISMEN",
         "reset() ile kullanici degisiminde tum lokal veri temizlenir (session, feature flags, journey ID). "
         "Yeni kullanici icin identify() cagirilir. Otomatik cihaz-ici merge mekanizmasi yok."),
        ("Cihaz degisimi senaryolarinda esleme",
         "SAGLANIYOR",
         "identify(distinctId:) ile backend'de kullanici eslesmesi. alias() metodu mevcut. "
         "Deferred deep link ile cihaz degisimi sonrasi attribution."),
        ("Device ID -> musteri numarasi baglama (anonim -> login merge)",
         "SAGLANIYOR",
         "identify() cagrisinda $anon_distinct_id otomatik olarak event'e eklenir. "
         "Backend tarafinda anonim eventler identified kullaniciya merge edilir."),
    ]))

    elements.extend(make_table("2.3 Tetikleme ve Kosullar", [
        ("Form abandon - aninda tetikleme",
         "KISMEN",
         "capture(event:properties:) ile uygulama tarafinda abandon event'i gonderilebilir. "
         "SDK'da built-in otomatik form abandon algilama mekanizmasi yok."),
        ("Form abandon - gecikmeli tetikleme (30dk / 24 saat)",
         "SAGLANMIYOR",
         "SDK'da zamanlanmis/gecikmeli tetikleme mekanizmasi yok. "
         "Backend tarafinda zamanlayici ile implemente edilmeli."),
        ("Tetikleme kosullarini pazarlama ekibi UI'dan tanimlayabilir mi",
         "BACKEND",
         "SDK event gonderir, tetikleme kurallari Paylisher dashboard/backend tarafinda tanimlanmali. "
         "Feature flags ile kismen kontrol edilebilir."),
        ("Frekans limiti (ayni kullaniciya)",
         "SAGLANMIYOR",
         "SDK'da frequency capping mekanizmasi bulunmuyor. "
         "Backend/dashboard tarafinda implemente edilmesi gerekir."),
    ]))

    elements.append(PageBreak())

    elements.extend(make_table("2.4 Push Notifications", [
        ("Push -> deeplink -> hedef ekran (state kaybi olmadan)",
         "SAGLANIYOR",
         "handleDeepLink() + pending deep link sistemi. hasPendingDeepLink, "
         "completePendingDeepLink() ile state korunur. Timeout timer mevcut."),
        ("Login gerektiren ekranlarda login sonrasi hedef ekrana yonlendirme",
         "SAGLANIYOR",
         "PaylisherDeepLinkHandler protokolu: paylisherDeepLinkRequiresAuth() callback'i. "
         "authParamRequired alani, auth=required URL parametresi, configurable authRequiredDestinations. "
         "Auth sonrasi completePendingDeepLink() ile hedefe navigasyon."),
        ("Sessiz push (background update)",
         "SAGLANIYOR",
         "NotificationManager'da silent flag destegi mevcut. "
         "silent='true' ise content.sound = nil yapilir."),
        ("iOS ve Android push delivery/open rate ayri raporlama",
         "BACKEND",
         "SDK event gonderir (push received, opened vb.). "
         "Raporlama tamamen backend/dashboard tarafinda saglanmali."),
    ]))

    elements.extend(make_table("2.5 In-App Mesajlar", [
        ("Ekran bazli tetikleme",
         "KISMEN",
         "screen() event'i ile ekran takibi yapiliyor. captureScreenViews=true ile "
         "otomatik screen event. Backend'de ekran bazli kural tanimlanabilir."),
        ("Davranis bazli tetikleme",
         "GELISTIRILIYOR",
         "actionBased notification tipi aktif olarak gelistiriliyor. "
         "Kosul mantigi backend'de tanimlanir, SDK uygulama tarafinda tetikleme alir."),
        ("Zaman bazli tetikleme",
         "SAGLANMIYOR",
         "SDK'da zaman bazli in-app veya push tetikleme mekanizmasi bulunmuyor. "
         "Backend/dashboard tarafinda implemente edilmesi gerekir."),
        ("Ayni mesaj icin A/B test",
         "KISMEN",
         "Feature flags uzerinden variant kontrolu (ornegin 'control' vs 'treatment'). "
         "getFeatureFlag() ile variant string alinir. $feature_flag_called event'i otomatik. "
         "Dedicated A/B test framework yok, feature flags ile saglanir."),
    ]))

    elements.extend(make_table("2.6 Event Tracking ve Servis Izleme", [
        ("Cekici cagiirma, hasar ihbari gibi servisleri ayri event olarak izleme",
         "SAGLANIYOR",
         "capture(event:properties:) ile custom event'ler: "
         "'cekici_basladi', 'cekici_basarili', 'cekici_hata'. "
         "Properties ile detay bilgi (error_code, service_name vb.) gonderilebilir."),
        ("Servis basarisizliklarinda hata kodlarini property olarak alma",
         "SAGLANIYOR",
         "Event properties icinde herhangi bir key-value gonderilebilir: "
         "capture('service_error', properties: ['error_code': 'TIMEOUT', 'http_status': 500])"),
        ("Feature usage raporlari",
         "KISMEN",
         "Event tracking ile kullanim verisi toplanir. sendFeatureFlagEvent=true ile "
         "$feature_flag_called event'i otomatik. Raporlama dashboard'da."),
        ("Tetiklenen mesajin conversion katkisi raporlanmasi",
         "KISMEN",
         "Journey tracking (jid) ile attribution. Event'lere jid, journey_source, "
         "journey_age_hours otomatik eklenir. 7 gun TTL. Conversion raporu backend'de."),
    ]))

    elements.append(PageBreak())

    elements.extend(make_table("2.7 Kullanici Davranis Analizi", [
        ("Formda ne kadar sure kalindigini alan bazinda olcme",
         "KISMEN",
         "Manuel olarak her alan icin giris/cikis event'i gonderilebilir. "
         "SDK'da otomatik form field tracking yok, capture() ile uygulama tarafinda yapilir."),
        ("Funnel icinde geri donuslu akislar izleme",
         "KISMEN",
         "Her adim icin event capture: 'step_1_start', 'step_back_to_1', 'step_2_complete'. "
         "Funnel analizi ve gorsellestirme backend/dashboard tarafinda."),
        ("Ayni kullanicinin farkli kampanyalardan tekrar teklif almasi",
         "SAGLANIYOR",
         "identify() ile tekil kullanici. Journey tracking ile kampanya kaynagi (journey_source). "
         "6 kaynak tipi: deeplink, deferredDeeplink, campaignResolution, push, email, custom."),
    ]))

    elements.extend(make_table("2.8 Dashboard ve Raporlama", [
        ("Funnel ve segment kirilimlarini ayni dashboard'da gorme",
         "BACKEND",
         "SDK veri toplar ve gonderir. Dashboard olusturma ve gorsellestirme "
         "tamamen backend/dashboard urunu kapsaminda."),
        ("Dashboard'lar pazarlama ekibi tarafindan kod yazmadan olusturulabilir mi",
         "BACKEND",
         "Tamamen backend/dashboard urunu. SDK kapsaminda degil."),
        ("Export / BI entegrasyonu (BigQuery, Looker vb.)",
         "BACKEND",
         "SDK kapsaminda degil. Backend tarafinda data pipeline ve "
         "BI entegrasyonu saglanmali."),
    ]))

    elements.extend(make_table("2.9 Gizlilik ve Performans", [
        ("KVKK - tekil kullanici verisi silme",
         "KISMEN",
         "SDK: reset() ile cihaz tarafinda tum veri temizlenir (storage, session, "
         "feature flags, journey ID). Backend: API ile sunucu tarafinda silme gerekir."),
        ("SDK'nin app performansina etkisi olcuelebilir mi",
         "KISMEN",
         "Debug mode ile log uretimi. Batch event gonderimi (flushAt=20, maxBatchSize=50). "
         "Gzip sikistirma. Built-in profiling yok, Xcode Instruments ile olculebilir."),
    ]))

    elements.extend(make_table("2.10 Cross-Channel ve Attribution", [
        ("App -> Push -> Satin alma cross-channel journey",
         "SAGLANIYOR",
         "PaylisherJourneyContext: journey ID tum event'lere otomatik eklenir. "
         "6 journey source: deeplink, deferredDeeplink, campaignResolution, push, email, custom. "
         "7 gun TTL ile journey takibi."),
        ("Push / in-app katkilari: Last click ve Assisted conversion ayrimi",
         "KISMEN",
         "Journey tracking + campaign attribution mevcut. Her event'te jid ve journey_source. "
         "Multi-touch attribution modeli SDK'da yok, backend'de analiz edilmeli."),
    ]))

    elements.extend(make_table("2.11 Diger Gereksinimler", [
        ("Test ortamda hatali surec raporlama",
         "SAGLANIYOR",
         "Custom event capture ile test ortaminda hata event'leri gonderilebilir. "
         "debug=true ile detayli loglama. ErrorHandlerRegistrar ile global error handler."),
        ("Harici data yukleyip push iletisimi (Excel ile data)",
         "BACKEND",
         "SDK kapsaminda degil. Backend/dashboard tarafinda bulk import ve "
         "push gonderimi yapilmali."),
    ]))

    # === Section 3 - SDK Technical Details ===
    elements.append(PageBreak())
    elements.append(Paragraph("3. SDK Teknik Detaylar", styles['SectionTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=PAYLISHER_BLUE, spaceAfter=8))

    elements.append(Paragraph("3.1 Desteklenen Platformlar", styles['SubSection']))
    platform_data = [
        [Paragraph("Platform", styles['TableHeader']),
         Paragraph("Min. Versiyon", styles['TableHeader']),
         Paragraph("Ozel Ozellikler", styles['TableHeader'])],
        [Paragraph("iOS", styles['TableCell']),
         Paragraph("13+", styles['TableCell']),
         Paragraph("Tam destek: push, in-app, session replay, deep link", styles['TableCell'])],
        [Paragraph("macOS", styles['TableCell']),
         Paragraph("-", styles['TableCell']),
         Paragraph("Event tracking, feature flags, identification", styles['TableCell'])],
        [Paragraph("tvOS", styles['TableCell']),
         Paragraph("-", styles['TableCell']),
         Paragraph("Event tracking, feature flags", styles['TableCell'])],
        [Paragraph("watchOS", styles['TableCell']),
         Paragraph("-", styles['TableCell']),
         Paragraph("Event tracking (reachability check yok)", styles['TableCell'])],
    ]
    pt = Table(platform_data, colWidths=[80, 80, 320])
    pt.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), TABLE_HEADER_BG),
        ('BACKGROUND', (0, 2), (-1, 2), ROW_ALT),
        ('BACKGROUND', (0, 4), (-1, 4), ROW_ALT),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#dddddd")),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
    ]))
    elements.append(pt)
    elements.append(Spacer(1, 6*mm))

    elements.append(Paragraph("3.2 In-App Mesaj Tipleri", styles['SubSection']))
    inapp_data = [
        [Paragraph("Tip", styles['TableHeader']),
         Paragraph("Aciklama", styles['TableHeader']),
         Paragraph("Icerik Bloklari", styles['TableHeader'])],
        [Paragraph("Native In-App", styles['TableCell']),
         Paragraph("Standart iOS modal: baslik, govde, gorsel, aksiyon butonu", styles['TableCell']),
         Paragraph("Basit yapi: title, body, imageUrl, actionUrl", styles['TableCell'])],
        [Paragraph("Modal", styles['TableCell']),
         Paragraph("Ozel tasarimli modal dialog", styles['TableCell']),
         Paragraph("Text, Image, Button, ButtonGroup, Spacer bloklari", styles['TableCell'])],
        [Paragraph("Modal Carousel", styles['TableCell']),
         Paragraph("Coklu sayfa carousel (%50 yukseklik)", styles['TableCell']),
         Paragraph("Sayfa bazli layout, navigasyon oklari, sayfa gostergesi", styles['TableCell'])],
        [Paragraph("Fullscreen Carousel", styles['TableCell']),
         Paragraph("Tam ekran carousel", styles['TableCell']),
         Paragraph("Ayni bloklar, tam ekran gorunum", styles['TableCell'])],
    ]
    it = Table(inapp_data, colWidths=[100, 190, 190])
    it.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), TABLE_HEADER_BG),
        ('BACKGROUND', (0, 2), (-1, 2), ROW_ALT),
        ('BACKGROUND', (0, 4), (-1, 4), ROW_ALT),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#dddddd")),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
    ]))
    elements.append(it)
    elements.append(Spacer(1, 6*mm))

    elements.append(Paragraph("3.3 Deep Link Mimarisi", styles['SubSection']))
    elements.append(Paragraph(
        "SDK, kapsamli bir deep link altyapisi sunar:",
        styles['BodyText2']
    ))
    dl_items = [
        "URL Scheme + Universal Links destegi",
        "Auth-required deep link handling (auth=required URL parametresi)",
        "Pending deep link mekanizmasi (login sonrasi hedef ekrana yonlendirme)",
        "Deferred deep linking (install attribution icin cihaz parmak izi eslesmesi)",
        "Journey tracking entegrasyonu (her deep link'e jid atanir)",
        "Campaign attribution (paylisher_campaign_key parametresi)",
        "Timeout timer ile pending link yonetimi",
    ]
    for item in dl_items:
        elements.append(Paragraph(f"  \u2022  {item}", styles['BodyText2']))
    elements.append(Spacer(1, 6*mm))

    elements.append(Paragraph("3.4 Event Batching ve Network", styles['SubSection']))
    batch_data = [
        [Paragraph("Parametre", styles['TableHeader']),
         Paragraph("Varsayilan", styles['TableHeader']),
         Paragraph("Aciklama", styles['TableHeader'])],
        [Paragraph("flushAt", styles['TableCell']),
         Paragraph("20", styles['TableCell']),
         Paragraph("Batch gondermeden once birikmesi gereken event sayisi", styles['TableCell'])],
        [Paragraph("maxQueueSize", styles['TableCell']),
         Paragraph("1000", styles['TableCell']),
         Paragraph("Kuyrukta tutulabilecek maksimum event sayisi", styles['TableCell'])],
        [Paragraph("maxBatchSize", styles['TableCell']),
         Paragraph("50", styles['TableCell']),
         Paragraph("Tek istekte gonderilecek maksimum event sayisi", styles['TableCell'])],
        [Paragraph("flushIntervalSeconds", styles['TableCell']),
         Paragraph("30", styles['TableCell']),
         Paragraph("Otomatik flush araligi (saniye)", styles['TableCell'])],
        [Paragraph("dataMode", styles['TableCell']),
         Paragraph(".any", styles['TableCell']),
         Paragraph("Network modu: .wifi, .cellular, .any", styles['TableCell'])],
    ]
    bt = Table(batch_data, colWidths=[110, 70, 300])
    bt.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), TABLE_HEADER_BG),
        ('BACKGROUND', (0, 2), (-1, 2), ROW_ALT),
        ('BACKGROUND', (0, 4), (-1, 4), ROW_ALT),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#dddddd")),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
    ]))
    elements.append(bt)

    # === Section 4 - Recommendations ===
    elements.append(PageBreak())
    elements.append(Paragraph("4. Oneriler ve Yol Haritasi", styles['SectionTitle']))
    elements.append(HRFlowable(width="100%", thickness=1, color=PAYLISHER_BLUE, spaceAfter=8))

    elements.append(Paragraph("4.1 SDK Tarafinda Gelistirilmesi Gereken Ozellikler", styles['SubSection']))
    sdk_recs = [
        ("Frekans Limiti (Frequency Capping)",
         "In-app mesaj ve push bildirimler icin kullanici bazli gosterim limiti. "
         "Ornek: Ayni mesaji 24 saatte en fazla 1 kez goster."),
        ("Gecikmeli Tetikleme (Delayed Triggers)",
         "Form abandon gibi senaryolar icin SDK tarafinda zamanlayici mekanizmasi. "
         "Ornek: 30 dakika sonra hatirlatma event'i olustur."),
        ("Otomatik Form Tracking",
         "Form field giris/cikis surelerini otomatik olcen mekanizma. "
         "Alan bazinda sure takibi icin built-in destek."),
    ]
    for title, desc in sdk_recs:
        elements.append(Paragraph(f"<b>{title}</b>", styles['BodyText2']))
        elements.append(Paragraph(desc, styles['SmallNote']))
        elements.append(Spacer(1, 2*mm))

    elements.append(Spacer(1, 4*mm))
    elements.append(Paragraph("4.2 Backend/Dashboard Tarafinda Saglanmasi Gereken Ozellikler", styles['SubSection']))
    backend_recs = [
        ("Dashboard Olusturma Arayuzu",
         "Pazarlama ekibinin kod yazmadan funnel, segment ve kampanya dashboard'lari olusturmasi."),
        ("BI Entegrasyonu",
         "BigQuery, Looker vb. sistemlere data export pipeline."),
        ("Tetikleme Kural Motoru",
         "Pazarlama ekibinin UI uzerinden ekran, davranis ve zaman bazli tetikleme kosullari tanimlamasi."),
        ("Multi-Touch Attribution",
         "Last click ve assisted conversion modellerinin backend'de hesaplanmasi."),
        ("Push Delivery/Open Rate Raporlama",
         "iOS ve Android icin ayri ayri delivery ve open rate metrikleri."),
        ("KVKK Veri Silme API",
         "Tekil kullanici verisinin sunucu tarafinda silinmesi icin API endpoint."),
        ("Bulk Data Import",
         "Excel/CSV ile harici data yukleyip push iletisimi."),
    ]
    for title, desc in backend_recs:
        elements.append(Paragraph(f"<b>{title}</b>", styles['BodyText2']))
        elements.append(Paragraph(desc, styles['SmallNote']))
        elements.append(Spacer(1, 2*mm))

    # === Footer on each page ===
    def footer(canvas, doc):
        canvas.saveState()
        canvas.setFont('Helvetica', 7)
        canvas.setFillColor(colors.HexColor("#999999"))
        canvas.drawString(18*mm, 10*mm, f"Paylisher PoC SDK Degerlendirme - {datetime.now().strftime('%d.%m.%Y')}")
        canvas.drawRightString(A4[0] - 18*mm, 10*mm, f"Sayfa {doc.page}")
        canvas.restoreState()

    doc.build(elements, onFirstPage=footer, onLaterPages=footer)
    return output_path

if __name__ == "__main__":
    path = build_pdf()
    print(f"PDF olusturuldu: {path}")
