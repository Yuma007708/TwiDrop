"use strict";

const $ = (id) => document.getElementById(id);

const form = $("form");
const urlInput = $("url");
const withMedia = $("with-media");
const previewBtn = $("preview-btn");
const saveBtn = $("save-btn");
const statusBox = $("status");
const previewBox = $("preview");
const resultBox = $("result");

function setStatus(message, isError = false) {
  if (!message) {
    statusBox.hidden = true;
    return;
  }
  statusBox.textContent = message;
  statusBox.classList.toggle("error", isError);
  statusBox.hidden = false;
}

function setBusy(busy) {
  previewBtn.disabled = busy;
  saveBtn.disabled = busy;
}

function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

async function postJSON(path, body) {
  const response = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.detail || `リクエストに失敗しました（HTTP ${response.status}）`);
  }
  return data;
}

function renderMedia(container, media) {
  container.replaceChildren();
  for (const item of media) {
    if (item.kind === "photo") {
      const img = document.createElement("img");
      img.src = item.thumbnail_url || item.url;
      img.alt = "添付画像";
      img.loading = "lazy";
      container.append(img);
    } else {
      const video = document.createElement("video");
      video.src = item.url;
      video.controls = true;
      video.preload = "metadata";
      if (item.thumbnail_url) video.poster = item.thumbnail_url;
      container.append(video);
    }
  }
}

function renderPreview(tweet) {
  const avatar = $("avatar");
  if (tweet.author_avatar_url) {
    avatar.src = tweet.author_avatar_url;
    avatar.hidden = false;
  } else {
    avatar.hidden = true;
  }

  $("author").textContent = `${tweet.author_name} @${tweet.author_screen_name}`;
  $("permalink").href = tweet.url;
  $("tweet-text").textContent = tweet.text || "(本文なし)";
  renderMedia($("media-list"), tweet.media || []);

  const parts = [];
  if (tweet.created_at) parts.push(new Date(tweet.created_at).toLocaleString("ja-JP"));
  if (tweet.like_count != null) parts.push(`いいね ${tweet.like_count.toLocaleString()}`);
  parts.push(tweet.media?.length ? `メディア ${tweet.media.length} 件` : "メディアなし");
  $("meta").textContent = parts.join(" ・ ");

  previewBox.hidden = false;
}

function renderFiles(files) {
  const list = $("file-list");
  list.replaceChildren();
  for (const file of files) {
    const item = document.createElement("li");
    const link = document.createElement("a");
    link.href = file.url;
    link.textContent = file.name;
    link.setAttribute("download", file.name);
    const size = document.createElement("span");
    size.className = "file-size";
    size.textContent = formatSize(file.size);
    item.append(link, size);
    list.append(item);
  }
  resultBox.hidden = files.length === 0;
}

async function loadSaved() {
  const list = $("saved-list");
  try {
    const response = await fetch("/api/saved");
    const data = await response.json();
    list.replaceChildren();
    if (!data.items.length) {
      const empty = document.createElement("li");
      empty.className = "empty";
      empty.textContent = "まだ保存されたツイートはありません。";
      list.append(empty);
      return;
    }
    for (const entry of data.items) {
      const item = document.createElement("li");
      item.className = "saved-item";
      const name = document.createElement("div");
      name.className = "saved-name";
      name.textContent = entry.name;
      const files = document.createElement("div");
      files.className = "saved-files";
      for (const file of entry.files) {
        const link = document.createElement("a");
        link.href = file.url;
        link.textContent = file.name;
        link.setAttribute("download", file.name);
        files.append(link);
      }
      item.append(name, files);
      list.append(item);
    }
  } catch {
    list.replaceChildren();
    const error = document.createElement("li");
    error.className = "empty";
    error.textContent = "一覧を読み込めませんでした。";
    list.append(error);
  }
}

async function handlePreview(event) {
  event.preventDefault();
  const url = urlInput.value.trim();
  if (!url) return;
  setBusy(true);
  setStatus("ツイートを取得しています…");
  try {
    const tweet = await postJSON("/api/tweet", { url });
    renderPreview(tweet);
    resultBox.hidden = true;
    setStatus("取得しました。内容を確認して「保存する」を押してください。");
  } catch (error) {
    previewBox.hidden = true;
    setStatus(error.message, true);
  } finally {
    setBusy(false);
  }
}

async function handleSave() {
  const url = urlInput.value.trim();
  if (!url) {
    setStatus("URL を入力してください。", true);
    return;
  }
  setBusy(true);
  setStatus("保存しています…（動画は時間がかかることがあります）");
  try {
    const data = await postJSON("/api/save", { url, with_media: withMedia.checked });
    renderPreview(data.tweet);
    renderFiles(data.files);
    const skipped = data.skipped.length ? `（${data.skipped.length} 件スキップ）` : "";
    setStatus(`保存しました: ${data.directory} ${skipped}`.trim());
    loadSaved();
  } catch (error) {
    setStatus(error.message, true);
  } finally {
    setBusy(false);
  }
}

form.addEventListener("submit", handlePreview);
saveBtn.addEventListener("click", handleSave);
loadSaved();
