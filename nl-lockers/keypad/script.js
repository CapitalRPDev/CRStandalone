window.addEventListener('message', function (event) {
    let e = event.data;
    switch (e.action) {
        case "KEYPAD":
            if (!e.value) {
                $('.keypad').css('display', 'none');
            } else {
                $('.keypad').css('display', 'flex');
            }
            break;
        case "KEYPAD_MOUSE":
            if (!e.value) {
                $('.mouse').css('display', 'none');
            } else {
                $('.mouse').css('display', 'flex');
            }
            break;
        case "DISPLAY":
            $('.display').text(e.value);
            break;
        case "BUTTON":
            HighlightButton(e.value);
            break;
        default: break;
    }
});

let prevBtnID = -1;

function HighlightButton(ID) {
    // Remove previous highlight
    if (prevBtnID > 0) {
        const prevBtn = document.getElementById('btn' + prevBtnID);
        if (prevBtn) prevBtn.classList.remove('active');
    }

    if (ID > 0) {
        const btn = document.getElementById('btn' + ID);
        if (btn) btn.classList.add('active');
        prevBtnID = ID;
    } else {
        prevBtnID = -1;
    }
}
