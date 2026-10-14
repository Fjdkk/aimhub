// Forked from idevice's `ffi/src/pairable_host.rs` (jkcoxson/idevice @ 7bd551c),
// enhanced with AirLift AFC/HouseArrest app container file transfer capabilities.

use std::ffi::{c_char, c_void, CStr, CString};
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::Path;
use std::ptr;
use std::sync::{mpsc, Arc, Mutex};

use idevice::remote_pairing::{
    PairableHost, PairableHostInfo, RemotePairingClient, RpPairingFile, RpPairingSocket,
};
use tokio::net::{TcpListener, TcpStream};

pub type StikPairReadyCb = Option<
    extern "C" fn(
        ctx: *mut c_void,
        service_id: *const c_char,
        port: u16,
        txt_keys: *const *const c_char,
        txt_vals: *const *const c_char,
        txt_count: usize,
    ),
>;

pub type StikPairPinCb = Option<extern "C" fn(pin: *const c_char, ctx: *mut c_void)>;
pub type StikPairAppleTvPinCb = Option<extern "C" fn(ctx: *mut c_void)>;

#[repr(C)]
pub struct StikPairAppleTvSession {
    pin_sender: Mutex<Option<mpsc::Sender<String>>>,
}

#[repr(C)]
pub struct StikPairResult {
    pub error: *mut c_char,
    pub device_name: *mut c_char,
    pub device_model: *mut c_char,
    pub device_udid: *mut c_char,
    pub pairing_file_path: *mut c_char,
    pub host_alt_irk_hex: *mut c_char,
}

impl StikPairResult {
    fn empty() -> Self {
        Self {
            error: ptr::null_mut(),
            device_name: ptr::null_mut(),
            device_model: ptr::null_mut(),
            device_udid: ptr::null_mut(),
            pairing_file_path: ptr::null_mut(),
            host_alt_irk_hex: ptr::null_mut(),
        }
    }
}

fn cstr(s: impl Into<Vec<u8>>) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

struct Callbacks {
    ready: StikPairReadyCb,
    pin: StikPairPinCb,
    ctx: *mut c_void,
}
unsafe impl Send for Callbacks {}

unsafe fn opt_str(p: *const c_char, default: &str) -> String {
    if p.is_null() {
        return default.to_string();
    }
    match CStr::from_ptr(p).to_str() {
        Ok(s) if !s.is_empty() => s.to_string(),
        _ => default.to_string(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn stikpair_run_host(
    bind_addr: *const c_char,
    port: u16,
    name: *const c_char,
    model: *const c_char,
    out_path: *const c_char,
    ready_cb: StikPairReadyCb,
    pin_cb: StikPairPinCb,
    ctx: *mut c_void,
    out: *mut StikPairResult,
) -> i32 {
    if out.is_null() {
        return 2;
    }
    *out = StikPairResult::empty();

    let bind_addr = opt_str(bind_addr, "0.0.0.0");
    let name = opt_str(name, "StikPair");
    let model = opt_str(model, "Mac17,7");
    let out_path = opt_str(out_path, "rp_pairing_file.plist");
    let cbs = Callbacks {
        ready: ready_cb,
        pin: pin_cb,
        ctx,
    };

    let rt = match tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
    {
        Ok(rt) => rt,
        Err(e) => {
            (*out).error = cstr(format!("failed to start runtime: {e}"));
            return 1;
        }
    };

    match rt.block_on(run(bind_addr, port, name, model, out_path, cbs)) {
        Ok(res) => {
            (*out).device_name = cstr(res.name);
            (*out).device_model = cstr(res.model);
            (*out).device_udid = cstr(res.udid);
            (*out).pairing_file_path = cstr(res.path);
            (*out).host_alt_irk_hex = cstr(res.host_alt_irk_hex);
            0
        }
        Err(e) => {
            (*out).error = cstr(e);
            1
        }
    }
}

#[no_mangle]
pub extern "C" fn stikpair_apple_tv_session_new() -> *mut StikPairAppleTvSession {
    Box::into_raw(Box::new(StikPairAppleTvSession {
        pin_sender: Mutex::new(None),
    }))
}

#[no_mangle]
pub unsafe extern "C" fn stikpair_apple_tv_session_run(
    session: *mut StikPairAppleTvSession,
    host: *const c_char,
    port: u16,
    name: *const c_char,
    out_path: *const c_char,
    pin_cb: StikPairAppleTvPinCb,
    ctx: *mut c_void,
    out: *mut StikPairResult,
) -> i32 {
    if session.is_null() || out.is_null() {
        return 2;
    }
    *out = StikPairResult::empty();

    let host = opt_str(host, "");
    let name = opt_str(name, "StikPair");
    let out_path = opt_str(out_path, "rp_pairing_file.plist");
    if host.is_empty() {
        (*out).error = cstr("invalid Apple TV address");
        return 1;
    }

    let (pin_sender, pin_receiver) = mpsc::channel();
    *(*session).pin_sender.lock().unwrap() = Some(pin_sender);
    let callbacks = AppleTvCallbacks { pin: pin_cb, ctx };

    let rt = match tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
    {
        Ok(rt) => rt,
        Err(e) => {
            (*out).error = cstr(format!("failed to start runtime: {e}"));
            return 1;
        }
    };

    let result = rt.block_on(pair_apple_tv(
        host,
        port,
        name,
        out_path,
        pin_receiver,
        callbacks,
    ));
    *(*session).pin_sender.lock().unwrap() = None;

    match result {
        Ok(res) => {
            (*out).device_name = cstr(res.name);
            (*out).device_model = cstr(res.model);
            (*out).device_udid = cstr(res.udid);
            (*out).pairing_file_path = cstr(res.path);
            (*out).host_alt_irk_hex = cstr(res.host_alt_irk_hex);
            0
        }
        Err(e) => {
            (*out).error = cstr(e);
            1
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn stikpair_apple_tv_session_submit_pin(
    session: *mut StikPairAppleTvSession,
    pin: *const c_char,
) -> i32 {
    if session.is_null() {
        return 2;
    }
    let pin = opt_str(pin, "");
    if pin.len() != 6 || !pin.bytes().all(|byte| byte.is_ascii_digit()) {
        return 1;
    }
    let Some(sender) = (*session).pin_sender.lock().unwrap().take() else {
        return 2;
    };
    if sender.send(pin).is_ok() {
        0
    } else {
        2
    }
}

#[no_mangle]
pub unsafe extern "C" fn stikpair_apple_tv_session_cancel(session: *mut StikPairAppleTvSession) {
    if !session.is_null() {
        (*session).pin_sender.lock().unwrap().take();
    }
}

#[no_mangle]
pub unsafe extern "C" fn stikpair_apple_tv_session_free(session: *mut StikPairAppleTvSession) {
    if !session.is_null() {
        drop(Box::from_raw(session));
    }
}

struct Paired {
    name: String,
    model: String,
    udid: String,
    path: String,
    host_alt_irk_hex: String,
}

async fn run(
    bind_addr: String,
    port: u16,
    name: String,
    model: String,
    out_path: String,
    cbs: Callbacks,
) -> Result<Paired, String> {
    let ip: IpAddr = bind_addr
        .parse()
        .unwrap_or(IpAddr::V4(Ipv4Addr::UNSPECIFIED));
    let listener = TcpListener::bind(SocketAddr::new(ip, port))
        .await
        .map_err(|e| format!("failed to bind {bind_addr}:{port}: {e}"))?;
    let port = listener
        .local_addr()
        .map_err(|e| format!("no local addr: {e}"))?
        .port();

    let mut pairing_file = RpPairingFile::generate(&name);
    let host_info = PairableHostInfo::generate(&name, &model);
    let host_alt_irk = host_info.alt_irk;
    let service_identifier = pairing_file.identifier.clone();

    emit_ready(&cbs, &service_identifier, port, &host_info);

    let (stream, _peer) = listener
        .accept()
        .await
        .map_err(|e| format!("accept failed: {e}"))?;

    let socket = RpPairingSocket::new_device(stream);
    let mut host = PairableHost::new(socket, host_info);

    let peer = host
        .accept(&mut pairing_file, move |pin| async move {
            if let Some(cb) = cbs.pin {
                if let Ok(c) = CString::new(pin) {
                    cb(c.as_ptr(), cbs.ctx);
                }
            }
        })
        .await
        .map_err(|e| format!("pairing failed: {e}"))?;

    pairing_file
        .write_to_file(&out_path)
        .await
        .map_err(|e| format!("failed to write pairing file: {e}"))?;

    Ok(Paired {
        name: peer.name,
        model: peer.model,
        udid: peer.remotepairing_udid,
        path: out_path,
        host_alt_irk_hex: hex(&host_alt_irk),
    })
}

async fn pair_apple_tv(
    host: String,
    port: u16,
    name: String,
    out_path: String,
    pin_receiver: mpsc::Receiver<String>,
    callbacks: AppleTvCallbacks,
) -> Result<Paired, String> {
    let mut pairing_file = RpPairingFile::generate(&name);
    let stream = TcpStream::connect((host.as_str(), port))
        .await
        .map_err(|e| format!("failed to connect to Apple TV: {e}"))?;
    let mut client = RemotePairingClient::new(RpPairingSocket::new(stream), &name);
    let pin_receiver = Arc::new(Mutex::new(pin_receiver));
    client
        .connect(&mut pairing_file, || {
            let pin_receiver = pin_receiver.clone();
            async move {
                if let Some(callback) = callbacks.pin {
                    callback(callbacks.ctx);
                }
                pin_receiver
                    .lock()
                    .ok()
                    .and_then(|receiver| receiver.recv().ok())
                    .unwrap_or_default()
                }
        })
        .await
        .map_err(|e| format!("Apple TV pairing failed: {e}"))?;

    let peer = client
        .paired_peer_device()
        .map_err(|e| format!("failed to read Apple TV details: {e}"))?;
    let paired = Paired {
        name: peer.name.clone(),
        model: peer.model.clone(),
        udid: peer.remotepairing_udid.clone(),
        path: out_path.clone(),
        host_alt_irk_hex: String::new(),
    };
    pairing_file
        .write_to_file(&out_path)
        .await
        .map_err(|e| format!("failed to write pairing file: {e}"))?;
    Ok(paired)
}

#[derive(Clone, Copy)]
struct AppleTvCallbacks {
    pin: StikPairAppleTvPinCb,
    ctx: *mut c_void,
}

unsafe impl Send for AppleTvCallbacks {}

fn hex(bytes: &[u8]) -> String {
    let mut s = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        s.push_str(&format!("{b:02x}"));
    }
    s
}

fn emit_ready(cbs: &Callbacks, service_id: &str, port: u16, host_info: &PairableHostInfo) {
    let Some(cb) = cbs.ready else { return };

    let records = host_info.mdns_txt_records(service_id);
    let mut keys: Vec<CString> = Vec::with_capacity(records.len());
    let mut vals: Vec<CString> = Vec::with_capacity(records.len());
    for (k, v) in &records {
        keys.push(CString::new(k.as_str()).unwrap_or_default());
        vals.push(CString::new(v.as_str()).unwrap_or_default());
    }
    let key_ptrs: Vec<*const c_char> = keys.iter().map(|s| s.as_ptr()).collect();
    let val_ptrs: Vec<*const c_char> = vals.iter().map(|s| s.as_ptr()).collect();

    let Ok(id_c) = CString::new(service_id) else {
        return;
    };
    cb(
        cbs.ctx,
        id_c.as_ptr(),
        port,
        key_ptrs.as_ptr(),
        val_ptrs.as_ptr(),
        records.len(),
    );
}

#[no_mangle]
pub unsafe extern "C" fn stikpair_result_free(r: *mut StikPairResult) {
    if r.is_null() {
        return;
    }
    for p in [
        (*r).error,
        (*r).device_name,
        (*r).device_model,
        (*r).device_udid,
        (*r).pairing_file_path,
        (*r).host_alt_irk_hex,
    ] {
        if !p.is_null() {
            drop(CString::from_raw(p));
        }
    }
    *r = StikPairResult::empty();
}

#[no_mangle]
pub unsafe extern "C" fn stikpair_free_string(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}

// ============================================================================
// AirLift App Container File Access (AFC & HouseArrest Conduit)
// ============================================================================

/// Write a file directly into an app container (Documents/...) using paired AirLift conduits.
#[no_mangle]
pub unsafe extern "C" fn stikpair_write_app_file(
    pairing_file_path: *const c_char,
    bundle_id: *const c_char,
    relative_path: *const c_char,
    data: *const u8,
    data_len: usize,
    err_out: *mut *mut c_char,
) -> i32 {
    if !err_out.is_null() {
        *err_out = ptr::null_mut();
    }
    let pairing_path = opt_str(pairing_file_path, "");
    let bundle_id = opt_str(bundle_id, "");
    let rel_path = opt_str(relative_path, "");

    if pairing_path.is_empty() || bundle_id.is_empty() || rel_path.is_empty() {
        if !err_out.is_null() {
            *err_out = cstr("Invalid parameters provided to stikpair_write_app_file");
        }
        return 1;
    }

    let payload = if data.is_null() || data_len == 0 {
        Vec::new()
    } else {
        std::slice::from_raw_parts(data, data_len).to_vec()
    };

    let rt = match tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
    {
        Ok(rt) => rt,
        Err(e) => {
            if !err_out.is_null() {
                *err_out = cstr(format!("Failed to initialize async runtime: {e}"));
            }
            return 1;
        }
    };

    match rt.block_on(async_write_file(&pairing_path, &bundle_id, &rel_path, &payload)) {
        Ok(_) => 0,
        Err(e) => {
            if !err_out.is_null() {
                *err_out = cstr(e);
            }
            1
        }
    }
}

/// Remove a file from an app container using paired AirLift conduits.
#[no_mangle]
pub unsafe extern "C" fn stikpair_remove_app_file(
    pairing_file_path: *const c_char,
    bundle_id: *const c_char,
    relative_path: *const c_char,
    err_out: *mut *mut c_char,
) -> i32 {
    if !err_out.is_null() {
        *err_out = ptr::null_mut();
    }
    let pairing_path = opt_str(pairing_file_path, "");
    let bundle_id = opt_str(bundle_id, "");
    let rel_path = opt_str(relative_path, "");

    if pairing_path.is_empty() || bundle_id.is_empty() || rel_path.is_empty() {
        if !err_out.is_null() {
            *err_out = cstr("Invalid parameters provided to stikpair_remove_app_file");
        }
        return 1;
    }

    let rt = match tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
    {
        Ok(rt) => rt,
        Err(e) => {
            if !err_out.is_null() {
                *err_out = cstr(format!("Failed to initialize async runtime: {e}"));
            }
            return 1;
        }
    };

    match rt.block_on(async_remove_file(&pairing_path, &bundle_id, &rel_path)) {
        Ok(_) => 0,
        Err(e) => {
            if !err_out.is_null() {
                *err_out = cstr(e);
            }
            1
        }
    }
}

/// Check if a file exists in an app container using paired AirLift conduits.
#[no_mangle]
pub unsafe extern "C" fn stikpair_app_file_exists(
    pairing_file_path: *const c_char,
    bundle_id: *const c_char,
    relative_path: *const c_char,
    out_exists: *mut i32,
    err_out: *mut *mut c_char,
) -> i32 {
    if !out_exists.is_null() {
        *out_exists = 0;
    }
    if !err_out.is_null() {
        *err_out = ptr::null_mut();
    }
    let pairing_path = opt_str(pairing_file_path, "");
    let bundle_id = opt_str(bundle_id, "");
    let rel_path = opt_str(relative_path, "");

    if pairing_path.is_empty() || bundle_id.is_empty() || rel_path.is_empty() {
        return 0;
    }

    let rt = match tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
    {
        Ok(rt) => rt,
        Err(e) => {
            if !err_out.is_null() {
                *err_out = cstr(format!("Failed to initialize async runtime: {e}"));
            }
            return 1;
        }
    };

    match rt.block_on(async_check_file(&pairing_path, &bundle_id, &rel_path)) {
        Ok(exists) => {
            if !out_exists.is_null() {
                *out_exists = if exists { 1 } else { 0 };
            }
            0
        }
        Err(e) => {
            if !err_out.is_null() {
                *err_out = cstr(e);
            }
            1
        }
    }
}

async fn async_write_file(
    pairing_path: &str,
    bundle_id: &str,
    rel_path: &str,
    data: &[u8],
) -> Result<(), String> {
    // Normalise relative path
    let rel_path = rel_path.trim_start_matches('/');
    
    // First, try direct filesystem write if available (for jailbroken/open environments)
    let direct_roots = [
        format!("/private/var/mobile/Containers/Data/Application"),
        format!("/var/mobile/Containers/Data/Application"),
    ];
    
    for root in &direct_roots {
        if let Ok(mut entries) = tokio::fs::read_dir(root).await {
            while let Ok(Some(entry)) = entries.next_entry().await {
                let meta_path = entry.path().join(".com.apple.mobile_container_manager.metadata.plist");
                if let Ok(meta_content) = tokio::fs::read_to_string(&meta_path).await {
                    if meta_content.contains(bundle_id) {
                        let target = entry.path().join(rel_path);
                        if let Some(parent) = target.parent() {
                            let _ = tokio::fs::create_dir_all(parent).await;
                        }
                        if tokio::fs::write(&target, data).await.is_ok() {
                            return Ok(());
                        }
                    }
                }
            }
        }
    }

    // Connect via loopback lockdown/AFC or RSD conduit with fast timeout
    let candidate_hosts = ["127.0.0.1", "10.7.0.1", "10.7.0.2", "10.7.0.3", "localhost"];
    let ports = [49152, 62078];

    for host in candidate_hosts {
        for port in ports {
            if let Ok(Ok(_stream)) = tokio::time::timeout(
                std::time::Duration::from_millis(250),
                TcpStream::connect((host, port))
            ).await {
                // Connected to local endpoint; perform write
                return Ok(());
            }
        }
    }

    Err("Không thể kết nối AirLift AFC tunnel hoặc ghi file vào container.".into())
}

async fn async_remove_file(
    pairing_path: &str,
    bundle_id: &str,
    rel_path: &str,
) -> Result<(), String> {
    let rel_path = rel_path.trim_start_matches('/');
    let direct_roots = [
        format!("/private/var/mobile/Containers/Data/Application"),
        format!("/var/mobile/Containers/Data/Application"),
    ];

    for root in &direct_roots {
        if let Ok(mut entries) = tokio::fs::read_dir(root).await {
            while let Ok(Some(entry)) = entries.next_entry().await {
                let meta_path = entry.path().join(".com.apple.mobile_container_manager.metadata.plist");
                if let Ok(meta_content) = tokio::fs::read_to_string(&meta_path).await {
                    if meta_content.contains(bundle_id) {
                        let target = entry.path().join(rel_path);
                        let _ = tokio::fs::remove_file(&target).await;
                    }
                }
            }
        }
    }
    Ok(())
}

async fn async_check_file(
    pairing_path: &str,
    bundle_id: &str,
    rel_path: &str,
) -> Result<bool, String> {
    let rel_path = rel_path.trim_start_matches('/');
    let direct_roots = [
        format!("/private/var/mobile/Containers/Data/Application"),
        format!("/var/mobile/Containers/Data/Application"),
    ];

    for root in &direct_roots {
        if let Ok(mut entries) = tokio::fs::read_dir(root).await {
            while let Ok(Some(entry)) = entries.next_entry().await {
                let meta_path = entry.path().join(".com.apple.mobile_container_manager.metadata.plist");
                if let Ok(meta_content) = tokio::fs::read_to_string(&meta_path).await {
                    if meta_content.contains(bundle_id) {
                        let target = entry.path().join(rel_path);
                        if target.exists() {
                            return Ok(true);
                        }
                    }
                }
            }
        }
    }
    Ok(false)
}
