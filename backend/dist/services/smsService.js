/**
 * Sends an SMS using the Onecodesoft API.
 *
 * @param number The 11-digit Bangladeshi mobile number (e.g. 88017XXXXXXXX)
 * @param message The SMS text content
 */
export async function sendSms(number, message) {
    const apiKey = 'pk9hZORJtjQdd0BTQCTi4RfoaV809jFdLr9LpiSo';
    // Use the sender ID provided in the documentation example
    const senderId = '8809617626047';
    // Format the number to ensure it starts with 880
    let formattedNumber = number.replace(/\D/g, ''); // Remove non-digits
    if (formattedNumber.length === 11 && formattedNumber.startsWith('01')) {
        formattedNumber = '88' + formattedNumber;
    }
    else if (formattedNumber.length === 13 && formattedNumber.startsWith('8801')) {
        // Already in correct format
    }
    else if (formattedNumber.length === 10 && formattedNumber.startsWith('1')) {
        formattedNumber = '880' + formattedNumber;
    }
    const url = new URL('https://sms.ocs-api.top/api/send-sms');
    url.searchParams.append('api_key', apiKey);
    url.searchParams.append('type', 'text');
    url.searchParams.append('number', formattedNumber);
    url.searchParams.append('senderid', senderId);
    url.searchParams.append('message', message);
    try {
        const response = await fetch(url.toString(), {
            method: 'GET',
        });
        const text = await response.text();
        console.log(`[sms] SMS API response for ${formattedNumber}: ${text}`);
        return response.ok;
    }
    catch (error) {
        console.error(`[sms] Failed to send SMS to ${formattedNumber}:`, error);
        return false;
    }
}
//# sourceMappingURL=smsService.js.map