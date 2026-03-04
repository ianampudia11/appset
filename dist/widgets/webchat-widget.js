(function() {

  let TOKEN = null;
  const currentScript = document.currentScript;
  if (currentScript && currentScript.dataset && currentScript.dataset.token) {
    TOKEN = currentScript.dataset.token;
  } else {

    try {
      const url = new URL(currentScript ? currentScript.src : window.location.href);
      TOKEN = url.searchParams.get('token');
    } catch (e) {

      if (currentScript && currentScript.src) {
        const match = currentScript.src.match(/[?&]token=([^&]+)/);
        if (match) TOKEN = match[1];
      }
    }
  }

  if (!TOKEN) {
    console.error('WebChat widget: Token not found. Please provide token via data-token attribute or ?token= query parameter.');
    return;
  }


  let API = null;


  if (currentScript && currentScript.src) {
    try {
      const scriptUrl = new URL(currentScript.src);
      API = scriptUrl.origin;
    } catch (e) {
      console.error('WebChat widget: Failed to parse currentScript.src:', e);
    }
  }


  if (!API) {
    const scripts = Array.from(document.getElementsByTagName('script'));
    for (let i = scripts.length - 1; i >= 0; i--) {
      const script = scripts[i];
      if (script.src && script.src.includes('/api/webchat/widget.js')) {
        try {
          const scriptUrl = new URL(script.src);
          API = scriptUrl.origin;
          break;
        } catch (e) {
          console.error('WebChat widget: Failed to parse script.src:', e);
        }
      }
    }
  }


  if (!API) {
    console.error('WebChat widget: Unable to determine API origin from script source. Please ensure the widget script is loaded from the correct URL.');
    return;
  }



  const WIDGET_ASSETS_BASE_URL = (function() {

    if (currentScript && currentScript.dataset && currentScript.dataset.assetsBaseUrl) {
      return currentScript.dataset.assetsBaseUrl;
    }

    return API + '/public/webchat';
  })();

  const SID_KEY = 'pc_webchat_sid_' + TOKEN;
  const PROFILE_KEY = 'pc_webchat_profile_' + TOKEN;

  let sid = localStorage.getItem(SID_KEY);
  let pollInterval = null;
  let lastPoll = null;
  let config = {};
  let selectedFile = null;
  const shownMsgIds = new Set();
  let tempMsgCounter = 0;
  let lastSentContent = null;
  let lastSentTime = 0;
  let lastTempMsgId = null;
  let isSending = false;


  const style = document.createElement('link');
  style.rel = 'stylesheet';
  style.href = WIDGET_ASSETS_BASE_URL + '/widget.css';

  style.onerror = function() {
    const fallbackStyle = document.createElement('link');
    fallbackStyle.rel = 'stylesheet';
    fallbackStyle.href = API + '/api/webchat/widget.css';
    document.head.appendChild(fallbackStyle);
  };
  document.head.appendChild(style);


  let emojiPickerLoadFailed = false;
  const emojiPickerTimeout = 5000; // 5 second timeout

  (function loadEmojiPicker() {
    const timeoutId = setTimeout(() => {
      if (!window.EmojiPicker) {
        console.warn('WebChat widget: Emoji picker failed to load within timeout, disabling emoji button');
        emojiPickerLoadFailed = true;
      }
    }, emojiPickerTimeout);


    const localScript = document.createElement('script');
    localScript.type = 'module';
    localScript.textContent = `
      try {
        const { Picker } = await import('${WIDGET_ASSETS_BASE_URL}/emoji-picker.js');
        window.EmojiPicker = Picker;
      } catch (localError) {
        console.warn('WebChat widget: Local emoji picker not available, falling back to CDN');
        try {
          const { Picker } = await import('https://cdn.jsdelivr.net/npm/emoji-picker-element@^1/index.js');
          window.EmojiPicker = Picker;
        } catch (cdnError) {
          console.error('WebChat widget: Failed to load emoji picker from CDN:', cdnError);
        }
      }
    `;

    localScript.onerror = function() {
      console.warn('WebChat widget: Failed to load emoji picker script');
      emojiPickerLoadFailed = true;
    };

    localScript.onload = function() {
      clearTimeout(timeoutId);
    };

    document.head.appendChild(localScript);
  })();


  const btn = document.createElement('button');
  btn.className = 'pc-widget-button';
  btn.innerHTML = `
    <svg width="24" height="24" viewBox="0 0 24 24" fill="white">
      <path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"/>
    </svg>
  `;
  document.body.appendChild(btn);


  const win = document.createElement('div');
  win.className = 'pc-widget-window';
  fetch(API + '/api/webchat/widget.html')
    .then(r => r.text())
    .then(html => {
      win.innerHTML = html;
      setupEventListeners();
    });
  document.body.appendChild(win);


  fetch(API + '/api/webchat/config/' + TOKEN)
    .then(r => r.json())
    .then(data => {
      config = data;
      applyConfig();
    })
    .catch(e => console.error('Failed to load widget config:', e));

  function applyConfig() {

    const theme = config.widgetColor || '#1c7cf5';
    const themeStart = adjustColor(theme, 20);
    const themeEnd = adjustColor(theme, -20);


    let themeStyle = document.getElementById('pc-theme-style');
    if (themeStyle) themeStyle.remove();
    themeStyle = document.createElement('style');
    themeStyle.id = 'pc-theme-style';
    themeStyle.textContent = `
      .pc-widget-header{background: linear-gradient(180deg, ${themeStart} 0%, ${themeEnd} 100%);} 
      .pc-send-btn{background:${theme} !important; box-shadow: 0 2px 8px ${hexToRgba(theme,0.35)};}
      .pc-out{background:${theme} !important;}
      .pc-widget-button{background:${theme} !important;}
      #pc-emoji-picker emoji-picker::part(search-wrapper){background: linear-gradient(180deg, ${themeStart} 0%, ${themeEnd} 100%);} 
      #pc-emoji-picker emoji-picker{--indicator-color:${theme}; --outline-color:${theme}; --button-active-background:${adjustColor(theme,40)};}
    `;
    document.head.appendChild(themeStyle);

    if (config.companyName) {
      const titleEl = win.querySelector('.pc-header-title');
      if (titleEl) {
        titleEl.textContent = `Talk with ${config.companyName}! 😊`;
      }
    }


    const applyPosition = (el) => {
      if (!el) return;
      el.style.right = el.style.left = '';
      el.style.transform = '';
      if (config.position === 'bottom-left') {
        el.style.left = '24px';
      } else if (config.position === 'bottom-center') {
        el.style.left = '50%';
        el.style.transform = 'translateX(-50%)';
      } else {
        el.style.right = '24px';
      }
    };
    applyPosition(win);
    applyPosition(btn);


    const avatarsContainer = win.querySelector('.pc-team-avatars');
    if (avatarsContainer) {
      avatarsContainer.style.display = config.showAvatar === false ? 'none' : 'flex';
    }


    if (config.teamAvatars && config.teamAvatars.length > 0 && avatarsContainer && config.showAvatar !== false) {

      const chatIcon = avatarsContainer.querySelector('.pc-avatar-chat');
      avatarsContainer.innerHTML = '';

      config.teamAvatars.forEach((member, index) => {
        const avatar = document.createElement('div');
        avatar.className = `pc-avatar pc-avatar-${index + 1}`;

        if (member.avatarUrl) {
          avatar.style.backgroundImage = `url(${member.avatarUrl})`;
          avatar.style.backgroundSize = 'cover';
          avatar.style.backgroundPosition = 'center';
        } else if (member.initials) {
          avatar.textContent = member.initials;
          avatar.style.display = 'flex';
          avatar.style.alignItems = 'center';
          avatar.style.justifyContent = 'center';
          avatar.style.fontSize = '16px';
          avatar.style.fontWeight = '600';
          avatar.style.color = 'white';
        }
        avatarsContainer.appendChild(avatar);
      });

      if (chatIcon) avatarsContainer.appendChild(chatIcon);
    }


    const attachBtn = win.querySelector('#pc-attach');
    if (attachBtn) attachBtn.style.display = config.allowFileUpload ? 'flex' : 'none';
  }

  function adjustColor(color, amount) {
    const num = parseInt((color || '#1c7cf5').replace('#', ''), 16);
    const r = Math.max(0, Math.min(255, (num >> 16) + amount));
    const g = Math.max(0, Math.min(255, ((num >> 8) & 0x00FF) + amount));
    const b = Math.max(0, Math.min(255, (num & 0x0000FF) + amount));
    return '#' + ((r << 16) | (g << 8) | b).toString(16).padStart(6, '0');
  }

  function hexToRgba(hex, alpha) {
    try {
      const c = hex.replace('#', '');
      const r = parseInt(c.substring(0, 2), 16);
      const g = parseInt(c.substring(2, 4), 16);
      const b = parseInt(c.substring(4, 6), 16);
      return `rgba(${r}, ${g}, ${b}, ${alpha})`;
    } catch { return `rgba(28,124,245,${alpha})`; }
  }

  function setupEventListeners() {
    const elMsgs = win.querySelector('#pc-messages');
    const elInput = win.querySelector('#pc-input');
    const elSend = win.querySelector('#pc-send');

    const elClose = win.querySelector('#pc-close');
    const elAttach = win.querySelector('#pc-attach');
    const elEmoji = win.querySelector('#pc-emoji');
    const elEmojiPicker = win.querySelector('#pc-emoji-picker');
    const elFileInput = win.querySelector('#pc-file-input');
    const elPreview = win.querySelector('#pc-preview');
    const elPreviewImg = win.querySelector('#pc-preview-img');
    const elPreviewFile = win.querySelector('#pc-preview-file');
    const elPreviewRemove = win.querySelector('#pc-preview-remove');
    let emojiPickerInstance = null;


    if (!elMsgs || !elInput || !elSend || !elAttach || !elEmoji || !elFileInput) {
      console.error('Widget elements not found, retrying...');
      setTimeout(setupEventListeners, 100);
      return;
    }


    if (btn) btn.onclick = () => {
      const isOpen = win.style.display === 'flex';
      win.style.display = isOpen ? 'none' : 'flex';
      

      if (!isOpen) {
        btn.innerHTML = `
          <svg width="24" height="24" viewBox="0 0 24 24" fill="white" stroke="white" stroke-width="2">
            <path d="M18 6L6 18M6 6l12 12"/>
          </svg>
        `;
        ensureSession().then(() => {
          startPolling();
          if (config.welcomeMessage && elMsgs.children.length === 0) {
            push('in', config.welcomeMessage, null, null);
          }
        });
      } else {
        btn.innerHTML = `
          <svg width="24" height="24" viewBox="0 0 24 24" fill="white">
            <path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"/>
          </svg>
        `;
        stopPolling();
      }
    };


    if (elClose) elClose.onclick = () => {
      win.style.display = 'none';
      stopPolling();
    };


    if (elAttach && elFileInput) elAttach.onclick = () => {
      elFileInput.click();
    };


    if (elEmoji && elEmojiPicker) {

      if (emojiPickerLoadFailed) {
        elEmoji.style.opacity = '0.3';
        elEmoji.style.cursor = 'not-allowed';
        elEmoji.title = 'Emoji picker unavailable';
        elEmoji.onclick = () => {
          console.warn('Emoji picker is not available');
        };
      } else {
        elEmoji.onclick = async () => {
          if (!emojiPickerInstance) {

            if (!window.EmojiPicker) {
              let attempts = 0;
              while (!window.EmojiPicker && attempts < 50) {
                await new Promise(resolve => setTimeout(resolve, 100));
                attempts++;
              }
              if (!window.EmojiPicker) {
                console.error('Emoji picker failed to load');

                elEmoji.style.opacity = '0.3';
                elEmoji.style.cursor = 'not-allowed';
                elEmoji.title = 'Emoji picker unavailable';
                return;
              }
            }


            emojiPickerInstance = new window.EmojiPicker();
            emojiPickerInstance.addEventListener('emoji-click', event => {

              const emoji = event.detail.unicode;
              const start = elInput.selectionStart;
              const end = elInput.selectionEnd;
              const text = elInput.value;
              elInput.value = text.substring(0, start) + emoji + text.substring(end);
              elInput.selectionStart = elInput.selectionEnd = start + emoji.length;
              elInput.focus();
            });
            elEmojiPicker.appendChild(emojiPickerInstance);
          }


          const isVisible = elEmojiPicker.style.display === 'block';
          elEmojiPicker.style.display = isVisible ? 'none' : 'block';
        };
      }
    }


    document.addEventListener('click', (e) => {
      if (elEmojiPicker && !elEmojiPicker.contains(e.target) && e.target !== elEmoji) {
        elEmojiPicker.style.display = 'none';
      }
    });


    if (elFileInput) elFileInput.onchange = (e) => {
      const file = e.target.files[0];
      if (!file) return;
      
      if (file.size > 10 * 1024 * 1024) {
        alert('File size must be less than 10MB');
        return;
      }
      
      selectedFile = file;
      showFilePreview(file);
    };


    if (elPreviewRemove) elPreviewRemove.onclick = () => {
      selectedFile = null;
      elPreview.style.display = 'none';
      elPreviewImg.style.display = 'none';
      elPreviewFile.style.display = 'none';
      elFileInput.value = '';
    };


    const sendMessage = async () => {

      if (isSending) return;
      
      const text = elInput.value.trim();
      if (!text && !selectedFile) return;


      isSending = true;
      elSend.disabled = true;
      elInput.disabled = true;
      elAttach.disabled = true;
      elSend.style.opacity = '0.5';
      elInput.style.opacity = '0.5';
      elAttach.style.opacity = '0.5';

      await ensureSession();

      if (selectedFile) {
        await sendFileMessage(selectedFile, text);
        selectedFile = null;
        elPreview.style.display = 'none';
        elFileInput.value = '';
      } else if (text) {

        const tempId = 'temp_' + (tempMsgCounter++);
        push('out', text, tempId, null);

        lastTempMsgId = tempId;
        lastSentContent = text;
        lastSentTime = Date.now();
        await sendTextMessage(text);
      }

      elInput.value = '';


      setTimeout(() => {
        isSending = false;
        elSend.disabled = false;
        elInput.disabled = false;
        elAttach.disabled = false;
        elSend.style.opacity = '1';
        elInput.style.opacity = '1';
        elAttach.style.opacity = '1';
        if (elInput && elInput.tagName === 'TEXTAREA') {
          elInput.focus();
          elInput.selectionStart = elInput.selectionEnd = elInput.value.length;
        }
      }, 1500);
    };

    if (elSend) elSend.onclick = sendMessage;
    if (elInput) elInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        sendMessage();
      }
    });


    const dropZone = win.querySelector('.pc-widget-messages');
    if (dropZone) {
      dropZone.ondragover = (e) => {
        e.preventDefault();
        dropZone.style.background = '#eef2ff';
      };
      dropZone.ondragleave = () => {
        dropZone.style.background = '#f9fafb';
      };
      dropZone.ondrop = (e) => {
        e.preventDefault();
        dropZone.style.background = '#f9fafb';
        const file = e.dataTransfer.files[0];
        if (file) {
          if (file.size > 10 * 1024 * 1024) {
            alert('File size must be less than 10MB');
            return;
          }
          selectedFile = file;
          showFilePreview(file);
        }
      };
    }
  }

  function showFilePreview(file) {
    const elPreview = win.querySelector('#pc-preview');
    const elPreviewImg = win.querySelector('#pc-preview-img');
    const elPreviewFile = win.querySelector('#pc-preview-file');

    if (file.type.startsWith('image/')) {
      const reader = new FileReader();
      reader.onload = (e) => {
        elPreviewImg.src = e.target.result;
        elPreviewImg.style.display = 'block';
        elPreviewFile.style.display = 'none';
        elPreview.style.display = 'block';
      };
      reader.readAsDataURL(file);
    } else if (file.type.startsWith('video/')) {
      elPreviewFile.innerHTML = `
        <div style="display: flex; align-items: center; gap: 8px;">
          <span style="font-size: 24px;">🎥</span>
          <div>
            <div style="font-weight: 600;">Video</div>
            <div style="font-size: 11px; opacity: 0.8;">${file.name}</div>
          </div>
        </div>
      `;
      elPreviewFile.style.display = 'block';
      elPreviewImg.style.display = 'none';
      elPreview.style.display = 'block';
    } else if (file.type.startsWith('audio/')) {
      elPreviewFile.innerHTML = `
        <div style="display: flex; align-items: center; gap: 8px;">
          <span style="font-size: 24px;">🎵</span>
          <div>
            <div style="font-weight: 600;">Audio</div>
            <div style="font-size: 11px; opacity: 0.8;">${file.name}</div>
          </div>
        </div>
      `;
      elPreviewFile.style.display = 'block';
      elPreviewImg.style.display = 'none';
      elPreview.style.display = 'block';
    } else if (file.type === 'application/pdf') {
      elPreviewFile.innerHTML = `
        <div style="display: flex; align-items: center; gap: 8px;">
          <span style="font-size: 24px;">📄</span>
          <div>
            <div style="font-weight: 600;">PDF Document</div>
            <div style="font-size: 11px; opacity: 0.8;">${file.name}</div>
          </div>
        </div>
      `;
      elPreviewFile.style.display = 'block';
      elPreviewImg.style.display = 'none';
      elPreview.style.display = 'block';
    } else {
      elPreviewFile.innerHTML = `
        <div style="display: flex; align-items: center; gap: 8px;">
          <span style="font-size: 24px;">📎</span>
          <div>
            <div style="font-weight: 600;">Document</div>
            <div style="font-size: 11px; opacity: 0.8;">${file.name}</div>
          </div>
        </div>
      `;
      elPreviewFile.style.display = 'block';
      elPreviewImg.style.display = 'none';
      elPreview.style.display = 'block';
    }
  }

  async function ensureSession() {
    if (!sid) {

      let profile = null;
      try { profile = JSON.parse(localStorage.getItem(PROFILE_KEY) || 'null'); } catch {}
      if (!profile || !profile.name || !profile.phone) {
        profile = await showPrechatForm();
        if (!profile) return; // user closed
      }

      const r = await fetch(API + '/api/webchat/session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token: TOKEN, visitorName: profile.name, visitorEmail: profile.email || '', visitorPhone: profile.phone })
      });
      const j = await r.json();
      sid = j.sessionId;
      localStorage.setItem(SID_KEY, sid);
    }
  }

  function showPrechatForm() {
    return new Promise((resolve) => {
      const overlay = win.querySelector('#pc-prechat');
      const nameEl = win.querySelector('#pc-prechat-name');
      const phoneEl = win.querySelector('#pc-prechat-phone');
      const emailEl = win.querySelector('#pc-prechat-email');
      const emailLabel = win.querySelector('#pc-prechat-email-label');
      const startBtn = win.querySelector('#pc-prechat-start');
      const errorEl = win.querySelector('#pc-prechat-error');

      if (config.collectEmail === false) {
        if (emailLabel) emailLabel.style.display = 'none';
        if (emailEl) emailEl.style.display = 'none';
      }

      try {
        const saved = JSON.parse(localStorage.getItem(PROFILE_KEY) || 'null');
        if (saved) {
          if (nameEl) nameEl.value = saved.name || '';
          if (phoneEl) phoneEl.value = saved.phone || '';
          if (emailEl) emailEl.value = saved.email || '';
        }
      } catch {}

      overlay.style.display = 'block';
      errorEl.style.display = 'none';
      errorEl.textContent = '';

      const submit = () => {
        const name = (nameEl.value || '').trim();
        const phone = (phoneEl.value || '').trim();
        const email = (emailEl?.value || '').trim();
        if (!name) { errorEl.textContent = 'Name is required'; errorEl.style.display = 'block'; return; }
        if (!phone || phone.replace(/\D/g,'').length < 6) { errorEl.textContent = 'Valid phone is required'; errorEl.style.display = 'block'; return; }
        const profile = { name, phone, email };
        localStorage.setItem(PROFILE_KEY, JSON.stringify(profile));
        overlay.style.display = 'none';
        resolve(profile);
      };

      startBtn.onclick = submit;
      [nameEl, phoneEl, emailEl].forEach(el => el && el.addEventListener('keydown', (e) => { if (e.key==='Enter') { e.preventDefault(); submit(); } }));
    });
  }

  function push(type, content, msgId, mediaUrl, fileType, timestamp) {
    const elMsgs = win.querySelector('#pc-messages');
    if (msgId && shownMsgIds.has(msgId)) return null;

    const div = document.createElement('div');
    div.className = 'pc-msg ' + (type === 'out' ? 'pc-out' : 'pc-in');
    if (msgId) div.dataset.msgId = String(msgId);

    if (mediaUrl) {
      const isBlob = mediaUrl.startsWith('blob:');

      const isImage = fileType?.startsWith('image/') || mediaUrl.match(/\.(jpg|jpeg|png|gif|webp)$/i);
      const isVideo = fileType?.startsWith('video/') || mediaUrl.match(/\.(mp4|webm|mov|avi)$/i);
      const isPDF = fileType === 'application/pdf' || mediaUrl.match(/\.pdf$/i);
      const isAudio = fileType?.startsWith('audio/') || mediaUrl.match(/\.(mp3|wav|ogg|aac|m4a)$/i);
      
      if (isImage) {
        const img = document.createElement('img');
        img.src = mediaUrl;
        img.className = 'pc-msg-media';
        img.style.maxWidth = '200px';
        img.style.borderRadius = '8px';
        img.style.cursor = 'pointer';
        img.onclick = () => {
          if (!isBlob) window.open(mediaUrl, '_blank');
        };
        div.appendChild(img);
      } else if (isVideo) {
        const video = document.createElement('video');
        video.src = mediaUrl;
        video.controls = true;
        video.className = 'pc-msg-media';
        video.style.maxWidth = '200px';
        video.style.borderRadius = '8px';
        div.appendChild(video);
      } else if (isAudio) {
        const audio = document.createElement('audio');
        audio.src = mediaUrl;
        audio.controls = true;
        audio.style.width = '200px';
        audio.style.marginBottom = '4px';
        div.appendChild(audio);
      } else if (isPDF) {
        const pdfDiv = document.createElement('div');
        pdfDiv.className = 'pc-msg-file';
        pdfDiv.innerHTML = `
          <span class=\"pc-msg-file-icon\" style=\"font-size: 32px;\">📄</span>
          <div class=\"pc-msg-file-info\">
            <div style=\"font-weight: 600;\">PDF Document</div>
            <div style=\"font-size: 11px; opacity: 0.8;\">Click to view</div>
          </div>
        `;
        pdfDiv.style.cursor = 'pointer';
        pdfDiv.onclick = () => window.open(mediaUrl, '_blank');
        div.appendChild(pdfDiv);
      } else {
        const fileDiv = document.createElement('div');
        fileDiv.className = 'pc-msg-file';
        fileDiv.innerHTML = `
          <span class=\"pc-msg-file-icon\">📎</span>
          <div class=\"pc-msg-file-info\">
            <div>${content || 'File attachment'}</div>
          </div>
        `;
        fileDiv.style.cursor = 'pointer';
        fileDiv.onclick = () => window.open(mediaUrl, '_blank');
        div.appendChild(fileDiv);
      }
      

      if (content) {
        const captionDiv = document.createElement('div');
        captionDiv.textContent = content;
        captionDiv.style.marginTop = '4px';
        div.appendChild(captionDiv);
      }
    } else if (content) {

      const textNode = document.createTextNode(content);
      div.appendChild(textNode);
    }

    const time = document.createElement('span');
    time.className = 'pc-msg-time';
    const ts = timestamp ? new Date(timestamp) : new Date();
    time.textContent = ts.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    div.appendChild(time);

    elMsgs.appendChild(div);
    elMsgs.scrollTop = elMsgs.scrollHeight;
    
    if (msgId) shownMsgIds.add(msgId);
    return div;
  }

  async function sendTextMessage(text) {
    try {
      const response = await fetch(API + '/api/webchat/message', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          token: TOKEN,
          sessionId: sid,
          message: text,
          messageType: 'text'
        })
      });


      if (response.ok) {
        const result = await response.json();
        if (result.message && lastTempMsgId) {

          const tempEl = win.querySelector(`[data-msg-id="${lastTempMsgId}"]`);
          if (tempEl) {
            tempEl.dataset.msgId = String(result.message.id);
            const timeEl = tempEl.querySelector('.pc-msg-time');
            if (timeEl) {
              const ts = new Date(result.message.sentAt || result.message.createdAt);
              timeEl.textContent = ts.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            }

            shownMsgIds.add(String(result.message.id));

            lastTempMsgId = null;
            lastSentContent = null;
          }
        }
      }
    } catch (e) {
      console.error('Failed to send message:', e);
    }
  }

  async function sendFileMessage(file, caption) {
    const formData = new FormData();
    formData.append('token', TOKEN);
    formData.append('sessionId', sid);
    formData.append('file', file);
    if (caption) formData.append('caption', caption);

    try {

      const localMediaUrl = URL.createObjectURL(file);
      

      const previewEl = push('out', caption || '', null, localMediaUrl, file.type, Date.now());
      
      const response = await fetch(API + '/api/webchat/upload', {
        method: 'POST',
        body: formData
      });

      if (!response.ok) {
        throw new Error('Upload failed');
      }
      

      const result = await response.json();
      if (result.mediaUrl) {
        URL.revokeObjectURL(localMediaUrl);
      }
      if (result.message && previewEl) {

        shownMsgIds.add(result.message.id);

        const mediaEl = previewEl.querySelector('img,video,audio');
        if (mediaEl && result.mediaUrl) mediaEl.src = result.mediaUrl;
        const timeEl = previewEl.querySelector('.pc-msg-time');
        if (timeEl) timeEl.textContent = new Date(result.message.sentAt || result.message.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        previewEl.dataset.msgId = String(result.message.id);
      }
    } catch (e) {
      console.error('Failed to send file:', e);
      alert('Failed to send file. Please try again.');
    }
  }

  async function pollMessages() {
    if (!sid) return;
    try {
      const url = API + '/api/webchat/messages/' + sid + '?token=' + TOKEN + (lastPoll ? '&since=' + lastPoll : '');
      const r = await fetch(url);
      const data = await r.json();

      if (data.messages) {
        data.messages.forEach(m => {

          if (m.direction === 'outbound') {

            push('in', m.content, m.id, m.mediaUrl, null, m.sentAt || m.createdAt);
          } else if (m.direction === 'inbound') {


            const within10s = Date.now() - (lastSentTime || 0) < 10000;
            const contentMatches = lastSentContent && m.content === lastSentContent;
            const mediaMatches = !m.mediaUrl; // Only match if no media (text messages only)

            if (within10s && contentMatches && mediaMatches) {
              const selector = lastTempMsgId ? `[data-msg-id="${lastTempMsgId}"]` : '.pc-msg.pc-out:last-child';
              const tempEl = win.querySelector(selector);
              if (tempEl) {
                tempEl.dataset.msgId = String(m.id);
                const timeEl = tempEl.querySelector('.pc-msg-time');
                if (timeEl) timeEl.textContent = new Date(m.sentAt || m.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                shownMsgIds.add(String(m.id));
                lastTempMsgId = null;
                lastSentContent = null;
                return; // skip pushing duplicate
              }
            }
            push('out', m.content, m.id, m.mediaUrl, null, m.sentAt || m.createdAt);
          }
        });
        if (data.timestamp) lastPoll = data.timestamp;
      }
    } catch (e) {
      console.error('Polling failed:', e);
    }
  }

  function startPolling() {
    if (pollInterval) return;
    pollMessages();
    pollInterval = setInterval(pollMessages, 3000);
  }

  function stopPolling() {
    if (pollInterval) {
      clearInterval(pollInterval);
      pollInterval = null;
    }
  }
})();
