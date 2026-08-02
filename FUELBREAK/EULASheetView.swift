import SwiftUI

// Extracted from the pre-tier PaywallView.swift, where it was declared
// `private`. PaywallView still presents it; it just no longer declares it.
//
// ⚠️ §3 of this text describes credit packs and per-period credit grants, and
// its auto-renewal terms imply everything renews — not true of lifetime Gold.
// Update before shipping.

struct EULASheetView: View {

    @Environment(\.dismiss) private var dismiss

    private let eulaText = """
    END USER LICENSE AGREEMENT (EULA)

    Sensaro – WILDFIRE PREDICTION & MONITORING APPLICATION

    EFFECTIVE DATE: May 4th, 2026

    PLEASE READ THIS END USER LICENSE AGREEMENT ("EULA" OR "AGREEMENT") CAREFULLY BEFORE DOWNLOADING, INSTALLING, ACCESSING, OR USING THE Sensaro MOBILE APPLICATION AND ANY RELATED SERVICES, FEATURES, CONTENT, WIDGETS, DATA, FORECASTS, MAPS, ALERTS, SUBSCRIPTION PRODUCTS, OR FUNCTIONALITY (COLLECTIVELY, THE "LICENSED APPLICATION") PROVIDED BY Sensaro TECHNOLOGIES, INC. ("DEVELOPER," "WE," "US," OR "OUR"). BY DOWNLOADING, INSTALLING, ACCESSING, OR USING THE LICENSED APPLICATION, YOU (THE "END-USER," "YOU," OR "YOUR") AGREE TO BE BOUND BY THE TERMS AND CONDITIONS OF THIS EULA, AS AMENDED FROM TIME TO TIME. IF YOU DO NOT AGREE TO THESE TERMS, DO NOT DOWNLOAD, INSTALL, ACCESS, OR USE THE LICENSED APPLICATION AND PROMPTLY DELETE IT FROM YOUR DEVICE.

    THIS EULA CONTAINS IMPORTANT DISCLAIMERS OF WARRANTIES, LIMITATIONS OF LIABILITY, AN AGREEMENT TO ARBITRATE DISPUTES (IN SECTION 18), A CLASS ACTION WAIVER, AND PROVISIONS THAT LIMIT YOUR RIGHTS AND REMEDIES. THE LICENSED APPLICATION IS PROVIDED FOR INFORMATIONAL PURPOSES ONLY AND IS NOT A SUBSTITUTE FOR OFFICIAL EMERGENCY WARNINGS, EVACUATION ORDERS, OR LIFE-SAFETY DECISIONS. YOU ASSUME ALL RISKS ASSOCIATED WITH YOUR USE OF THE LICENSED APPLICATION. FIRE BEHAVIOR IS INHERENTLY UNPREDICTABLE; THE DEVELOPER MAKES NO GUARANTEE, REPRESENTATION, OR WARRANTY AS TO THE ACCURACY, COMPLETENESS, TIMELINESS, OR RELIABILITY OF ANY WILDFIRE DATA, PREDICTION, MODEL OUTPUT, HEAT PERIMETER, SPREAD FORECAST, AIR QUALITY INDEX, EVACUATION ROUTE, OR ANY OTHER CONTENT DISPLAYED WITHIN THE LICENSED APPLICATION.

    1. ACKNOWLEDGMENT
    You and the End-User acknowledge that this EULA is concluded between You and the Developer only, and not with Apple Inc. ("Apple"), and the Developer, not Apple, is solely responsible for the Licensed Application and the content thereof. The EULA may not provide for usage rules for the Licensed Application that are in conflict with the Apple Media Services Terms and Conditions as of the Effective Date (which You acknowledge You have had the opportunity to review). The Developer is solely responsible for compliance with all applicable laws, regulations, and industry standards in connection with the Licensed Application. Any questions, complaints, or claims regarding the Licensed Application should be directed to the Developer using the contact information set forth in Section 17 of this EULA.

    2. SCOPE OF LICENSE
    Subject to Your strict compliance with all terms and conditions of this EULA and the Usage Rules set forth in the Apple Media Services Terms and Conditions (the "Usage Rules"), the Developer hereby grants to You a limited, non-exclusive, non-transferable, non-sublicensable, revocable license to download, install, and use the Licensed Application solely for Your personal, non-commercial, lawful purposes on any Apple-branded products that You own or control and as permitted by the Usage Rules, and solely as expressly authorized herein. This license does not allow the Licensed Application to be used on any device that You do not own or control, except that the Licensed Application may be accessed and used by other accounts associated with the purchaser via Family Sharing or volume purchasing in accordance with Apple's terms. You may not rent, lease, lend, sell, redistribute, sublicense, decompile, reverse engineer, disassemble, attempt to derive the source code of, modify, or create derivative works of the Licensed Application, any updates, or any part thereof (except as and only to the extent that any foregoing restriction is prohibited by applicable law or to the extent as may be permitted by the licensing terms governing use of any open-sourced components included with the Licensed Application). Any attempt to do so is a violation of the rights of the Developer and its licensors. The Licensed Application is licensed, not sold, to You.

    3. SUBSCRIPTION SERVICES, PAYMENTS, AND AUTO-RENEWAL TERMS
    Certain features, functionalities, content, enhanced data layers, real-time fire spread forecasts, custom alert zones, historical fire analytics, and premium map overlays within the Licensed Application may be provided only on a paid subscription basis (the "Subscription Services"). The Licensed Application may offer multiple subscription options, including, but not limited to, monthly subscriptions, annual subscriptions, or weekly subscriptions (each a "Subscription Period"). If You elect to purchase a subscription, You agree to the following terms, which constitute a binding contract between You and the Developer for the provision of Subscription Services, with billing processed through Your Apple ID account and governed by the Apple Media Services Terms and Conditions.

    3.1 Subscription Purchase. Payment for Subscription Services will be charged to Your Apple ID account at confirmation of purchase. Pricing displayed within the Licensed Application may vary by geographic location and is subject to change as set forth herein. All fees are non-refundable except as required by applicable law or as specifically set forth in Apple's refund policy.

    3.2 Auto-Renewal and Cancellation. Unless You cancel at least twenty-four (24) hours before the end of the current Subscription Period, Your subscription will automatically renew for an additional Subscription Period of the same duration at the then-current renewal price. The renewal charge will be applied to your Apple ID account within twenty-four (24) hours prior to the end of the current Subscription Period. You may manage or cancel auto-renewal at any time by visiting Your Account Settings on the App Store after purchase. Upon cancellation, You will continue to have access to the Subscription Services for the remainder of the Subscription Period that You have already paid for; no partial refunds will be provided for unused portions of the Subscription Period unless otherwise required by applicable law. Deleting the Licensed Application from Your device does not cancel Your subscription; You must expressly cancel the subscription through Apple's subscription management interface.

    3.3 Free Trials. From time to time, the Developer may offer free trial periods for select Subscription Services. If You sign up for a free trial that converts to a paid subscription, You acknowledge that unless You cancel the subscription at least twenty-four (24) hours before the end of the free trial period, You will be automatically charged the applicable subscription fee for the first Subscription Period upon the expiration of the free trial. Any unused portion of a free trial period will be forfeited if You purchase a paid subscription before the end of the trial period.

    3.4 Price Changes. The Developer reserves the right to modify, increase, or adjust the subscription fees for any Subscription Period at any time. Any price change will become effective no earlier than the next renewal of your Subscription Period after the Developer has provided You with reasonable prior notice of the change. If You do not agree to a price change, You may cancel Your subscription before the change takes effect in accordance with the cancellation procedure above. Your continued use of the Subscription Services after a price change constitutes Your acceptance of the new fee.

    3.5 No Obligation to Continue Offering Subscriptions. The Developer reserves the right to modify, suspend, or discontinue any Subscription Service, feature tier, or content offering, in whole or in part, at any time without prior notice or liability, except as prohibited by law. In the event of discontinuation of a Subscription Service for which You have prepaid, the Developer may, in its sole discretion, provide a prorated refund, or You may seek a refund from Apple in accordance with Apple's applicable policies.

    3.6 Taxes. You are responsible for any applicable national, state, local, or foreign taxes, duties, or levies associated with Your subscription purchase, other than taxes based on Developer's net income.

    4. MAINTENANCE AND SUPPORT
    The Developer is solely responsible for providing any maintenance and support services with respect to the Licensed Application, as specified in this EULA, or as required under applicable law. You and the End-User acknowledge that Apple has no obligation whatsoever to furnish any maintenance and support services with respect to the Licensed Application. The Developer may, but is not required to, provide updates, bug fixes, enhancements, or new versions of the Licensed Application. The Developer reserves the right to charge fees for any future releases or enhanced functionality. Any such updates shall be governed by this EULA unless separate terms are provided by the Developer. The Developer shall not be liable for any failure to provide support, update, or correct defects in the Licensed Application. All support requests should be directed solely to the Developer at the contact information provided in Section 17.

    5. WARRANTY DISCLAIMER
    TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE LICENSED APPLICATION AND ALL SUBSCRIPTION SERVICES ARE PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS WITHOUT WARRANTY OF ANY KIND. THE DEVELOPER DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, ACCURACY, AND NON-INFRINGEMENT. WILDFIRE BEHAVIOR IS CHAOTIC AND CANNOT BE PREDICTED WITH CERTAINTY. THE LICENSED APPLICATION IS A SUPPLEMENTAL INFORMATIONAL TOOL ONLY.

    6. LIMITATION OF LIABILITY
    TO THE FULLEST EXTENT PERMITTED BY LAW, THE DEVELOPER SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES. THE DEVELOPER'S TOTAL AGGREGATE LIABILITY SHALL NOT EXCEED THE GREATER OF THE AMOUNT YOU PAID IN THE PRECEDING 12 MONTHS OR USD $10.00. THE LICENSED APPLICATION IS NOT AN OFFICIAL EMERGENCY NOTIFICATION SYSTEM. ALWAYS FOLLOW INSTRUCTIONS FROM LOCAL EMERGENCY OFFICIALS.

    7. PRODUCT CLAIMS
    The Developer, not Apple, is responsible for addressing any claims relating to the Licensed Application, including product liability claims, regulatory compliance claims, and consumer protection claims.

    8. INTELLECTUAL PROPERTY
    The Licensed Application and all content therein are the exclusive property of the Developer or its licensors. All rights not expressly granted are reserved. You may not use data mining, scraping, or similar methods in connection with the Licensed Application, nor use it to develop competing wildfire prediction services.

    9. LEGAL COMPLIANCE
    You represent that You are not located in a U.S.-embargoed country and are not listed on any U.S. Government prohibited parties list. You shall comply with all applicable laws in connection with Your use of the Licensed Application.

    10. THIRD-PARTY DATA
    Wildfire data, satellite imagery, weather feeds, and air quality indices may be provided by third parties (e.g., NOAA, NASA, USGS). Your use of such data is subject to those providers' terms. The Developer does not warrant the accuracy or reliability of third-party content.

    11. PRIVACY AND DATA COLLECTION
    Your use is subject to the Developer's Privacy Policy at https://www.sensaro.net/Mobile/Privacy-Policy/FUELBREAK-Twin_Timbers.html. By using the Licensed Application, You consent to collection and use of Your information as described therein, including precise location data if permission is granted.

    12. TERMINATION
    This EULA is effective until terminated. Your rights terminate automatically upon any breach. The Developer may terminate at any time with or without cause. Sections 5, 6, 8, 11, 13, and 18 survive termination.

    13. INDEMNIFICATION
    You agree to indemnify and hold harmless the Developer from any claims arising out of Your violation of this EULA, misuse of the Licensed Application, or violation of any third-party rights or applicable law.

    14. EXPORT REGULATION
    You shall not export or re-export any portion of the Licensed Application in violation of applicable U.S. export control laws.

    15. FORCE MAJEURE
    The Developer shall not be liable for delays or failures resulting from causes beyond its reasonable control, including wildfires, natural disasters, internet outages, cyberattacks, or government orders.

    16. NO EMERGENCY SERVICES
    THE LICENSED APPLICATION DOES NOT PROVIDE FIRE DETECTION OR EMERGENCY RESPONSE SERVICES. DO NOT RELY ON IT AS YOUR PRIMARY SOURCE OF LIFE-SAFETY INFORMATION. ALWAYS CONTACT 911 AND FOLLOW OFFICIAL EMERGENCY DIRECTIVES.

    17. CONTACT
    Sensaro Technologies, Inc.
    Email: contact@sensaro.net
    Web: https://www.sensaro.net

    18. GOVERNING LAW AND DISPUTE RESOLUTION
    This EULA is governed by the laws of the State of Delaware. Any disputes shall be resolved by binding arbitration administered by the AAA on an individual basis. You waive any right to a jury trial or class action. You may opt out of arbitration within 30 days of first acceptance by emailing contact@sensaro.net.

    19. THIRD-PARTY BENEFICIARY
    Apple and its subsidiaries are third-party beneficiaries of this EULA and may enforce it against You.

    20. GENERAL
    This EULA constitutes the entire agreement between You and the Developer. If any provision is held invalid, the remaining provisions remain in effect. The Developer may amend this EULA at any time by posting an updated version; continued use constitutes acceptance.

    BY USING THE LICENSED APPLICATION, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO BE BOUND BY THIS EULA.
    """

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.12, blue: 0.04).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Terms of Use")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(red: 0.04, green: 0.12, blue: 0.04))

                Divider().background(Color.white.opacity(0.1))

                ScrollView {
                    Text(eulaText)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(4)
                        .padding(20)
                }
            }
        }
    }
}
