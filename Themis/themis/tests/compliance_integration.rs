use themis::compliance::types::*;
use themis::compliance::*;

fn make_token(text: &str, x: u32, y: u32, width: u32, height: u32, panel: &str) -> OcrToken {
    OcrToken {
        text: text.to_string(),
        confidence: 0.95,
        bbox: BoundingBox {
            x,
            y,
            width,
            height,
        },
        source_image: Some(panel.to_string()),
    }
}

#[test]
fn test_oats_multi_panel_compliance_fixture() {
    let mut tokens = Vec::new();

    // Panel 1: Nutrition facts table (contains misleading numbers like "Zinc 10")
    tokens.push(make_token("NUTRITION INFORMATION", 100, 100, 200, 30, "panel_1_nutrition.jpg"));
    tokens.push(make_token("Per 100g", 100, 140, 100, 25, "panel_1_nutrition.jpg"));
    tokens.push(make_token("Energy 400 kcal", 100, 170, 150, 25, "panel_1_nutrition.jpg"));
    tokens.push(make_token("Protein 12 g", 100, 200, 120, 25, "panel_1_nutrition.jpg"));
    tokens.push(make_token("Carbohydrate 68 g", 100, 230, 160, 25, "panel_1_nutrition.jpg"));
    tokens.push(make_token("Zinc (mg) 10", 100, 260, 140, 25, "panel_1_nutrition.jpg"));

    // Panel 2: Legal declarations & MRP
    tokens.push(make_token("Net Qty.:", 1300, 900, 100, 35, "panel_2_declarations.jpg"));
    tokens.push(make_token("460g", 1410, 900, 60, 35, "panel_2_declarations.jpg"));
    tokens.push(make_token("(400g+60gFree)", 1480, 900, 140, 35, "panel_2_declarations.jpg"));

    tokens.push(make_token("MRPE", 1441, 1015, 39, 126, "panel_2_declarations.jpg"));
    tokens.push(make_token("Cinci, of", 1393, 1012, 35, 126, "panel_2_declarations.jpg"));
    tokens.push(make_token("100.00", 1361, 1278, 49, 168, "panel_2_declarations.jpg"));
    tokens.push(make_token("all taxes):", 1347, 1008, 35, 161, "panel_2_declarations.jpg"));

    tokens.push(make_token("Unit Sale Price: Rs. 0.22 / g", 1300, 1100, 220, 35, "panel_2_declarations.jpg"));
    tokens.push(make_token("Pkd. 15 JUN 2026", 1300, 1200, 180, 35, "panel_2_declarations.jpg"));
    tokens.push(make_token("Country of Origin: India", 1300, 1300, 200, 35, "panel_2_declarations.jpg"));
    tokens.push(make_token("Manufactured by: Oats India Pvt. Ltd., Industrial Area, Pincode 122001", 1300, 1400, 500, 35, "panel_2_declarations.jpg"));
    tokens.push(make_token("Customer Care:", 1300, 1500, 150, 35, "panel_2_declarations.jpg"));
    tokens.push(make_token("feedback", 1300, 1540, 90, 30, "panel_2_declarations.jpg"));
    tokens.push(make_token("oatsconsumer.com", 1400, 1540, 160, 30, "panel_2_declarations.jpg"));
    tokens.push(make_token("1800-180-2222", 1300, 1580, 160, 30, "panel_2_declarations.jpg"));

    let report = evaluate_compliance_with_quality(
        &tokens,
        2000,
        2000,
        Some("Oats Pouch 460g".to_string()),
        vec!["panel_1_nutrition.jpg".to_string(), "panel_2_declarations.jpg".to_string()],
        vec![],
    );

    // 1. MRP must be 100.00, NOT 10 from Zinc (mg) 10 on panel 1
    let mrp_eval = report.evaluations.iter().find(|e| e.field == DeclarationField::MaximumRetailPrice).unwrap();
    assert_eq!(mrp_eval.status, Status::Compliant);
    assert!(mrp_eval.detected_text.as_ref().unwrap().contains("100.00"), "Expected MRP 100.00, got: {:?}", mrp_eval.detected_text);
    assert!(mrp_eval.detected_text.as_ref().unwrap().contains("all taxes"));

    // 2. Net Quantity must be 460g, NOT 12g or 68g from nutrition
    let qty_eval = report.evaluations.iter().find(|e| e.field == DeclarationField::NetQuantity).unwrap();
    assert_eq!(qty_eval.status, Status::Compliant);
    assert!(qty_eval.detected_text.as_ref().unwrap().contains("460 g"), "Expected Net Qty 460 g, got: {:?}", qty_eval.detected_text);

    // 3. Mfg Date must be 15 JUN 2026
    let mfg_eval = report.evaluations.iter().find(|e| e.field == DeclarationField::ManufactureDate).unwrap();
    assert_eq!(mfg_eval.status, Status::Compliant);
    assert!(mfg_eval.detected_text.as_ref().unwrap().contains("15 JUN 2026"));

    // 4. Country of Origin must be India
    let origin_eval = report.evaluations.iter().find(|e| e.field == DeclarationField::CountryOfOrigin).unwrap();
    assert_eq!(origin_eval.status, Status::Compliant);
    assert!(origin_eval.detected_text.as_ref().unwrap().contains("India"));

    // 5. Stitched email for consumer care
    let care_eval = report.evaluations.iter().find(|e| e.field == DeclarationField::ConsumerCare).unwrap();
    assert_eq!(care_eval.status, Status::Compliant);

    // 6. Overall compliance must be 100% and Compliant risk tier
    assert_eq!(report.risk_tier, RiskTier::Compliant);
    assert_eq!(report.overall_compliant, true);
    assert_eq!(report.violations.total_violations, 0);
}

#[test]
fn test_dishwasher_columnar_and_truncated_unit() {
    let tokens = vec![
        make_token("Dishwasher Gel", 100, 100, 300, 40, "front.jpg"),
        make_token("Net Vol: 500m", 100, 200, 180, 30, "front.jpg"),
        make_token("MRP Rs. 149.00 incl. of all taxes", 100, 250, 350, 30, "front.jpg"),
        make_token("Pkd: 01/2026", 100, 300, 150, 30, "front.jpg"),
        make_token("Made in India", 100, 350, 150, 30, "front.jpg"),
        make_token("Mfg by: Clean Chem Ltd, Industrial Area, Pincode 400001", 100, 400, 500, 30, "front.jpg"),
        make_token("Consumer Care: care@cleanchem.in, 1800-222-333", 100, 450, 450, 30, "front.jpg"),
    ];

    let report = evaluate_compliance_with_quality(
        &tokens,
        1000,
        1000,
        Some("Dishwasher 500ml".to_string()),
        vec!["front.jpg".to_string()],
        vec![],
    );

    let qty_eval = report.evaluations.iter().find(|e| e.field == DeclarationField::NetQuantity).unwrap();
    assert_eq!(qty_eval.status, Status::Compliant);
    assert!(qty_eval.detected_text.as_ref().unwrap().contains("500 ml"));

    let mrp_eval = report.evaluations.iter().find(|e| e.field == DeclarationField::MaximumRetailPrice).unwrap();
    assert_eq!(mrp_eval.status, Status::Compliant);
    assert!(mrp_eval.detected_text.as_ref().unwrap().contains("149.00"));

    assert_eq!(report.risk_tier, RiskTier::Compliant);
}

#[test]
fn test_maggi_nutrition_macro_rejection() {
    let tokens = vec![
        make_token("MAGGI 2-Minute Noodles", 50, 50, 250, 30, "back.jpg"),
        make_token("Nutritional Facts per 100g", 50, 100, 250, 25, "back.jpg"),
        make_token("Protein 8.8g", 50, 130, 120, 25, "back.jpg"),
        make_token("Total Fat 14.3g", 50, 160, 140, 25, "back.jpg"),
        make_token("Carbohydrate 63.5g", 50, 190, 170, 25, "back.jpg"),
        make_token("Net Weight: 70g", 50, 300, 150, 30, "back.jpg"),
        make_token("MRP Rs 14.00 (incl. of all taxes)", 50, 350, 300, 30, "back.jpg"),
        make_token("Mfg Date: 05/2026", 50, 400, 160, 30, "back.jpg"),
        make_token("Country of Origin: India", 50, 450, 200, 30, "back.jpg"),
        make_token("Marketed by: Nestle India Ltd, Pincode 110001", 50, 500, 400, 30, "back.jpg"),
        make_token("WECARE eIN.NESTLECOM", 50, 550, 250, 30, "back.jpg"),
        make_token("1800-222-6888", 50, 590, 180, 30, "back.jpg"),
    ];

    let report = evaluate_compliance_with_quality(
        &tokens,
        800,
        800,
        Some("Noodles 70g".to_string()),
        vec!["back.jpg".to_string()],
        vec![],
    );

    let qty_eval = report.evaluations.iter().find(|e| e.field == DeclarationField::NetQuantity).unwrap();
    assert_eq!(qty_eval.status, Status::Compliant);
    assert!(qty_eval.detected_text.as_ref().unwrap().contains("70 g"));

    let care_eval = report.evaluations.iter().find(|e| e.field == DeclarationField::ConsumerCare).unwrap();
    assert_eq!(care_eval.status, Status::Compliant);
    assert!(care_eval.detected_text.as_ref().unwrap().contains("wecare@ein.nestlecom"));

    assert_eq!(report.risk_tier, RiskTier::Compliant);
}
