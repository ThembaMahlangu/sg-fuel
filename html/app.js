import { TRANSLATIONS } from "./translations.js";

const $ = (selector) => document.querySelector(selector);

const $post = async (url, data) => {
    if (!url.startsWith("/")) url = `/${url}`;

    const result = await fetch(`https://sg-fuel${url}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
        },
        body: JSON.stringify(data ?? {}),
    });

    try {
        return await result.json();
    } catch (e) {
        return {};
    }
};

// State
let LITER_PRICE = 5;
let CURRENT_FUEL = 0;
const MAX_LITER = 100;

let fuelingData = {
    targetLitres: 0,
    currentLitres: 0,
    pricePerLitre: 0,
    totalCost: 0,
    isActive: false,
    startTime: 0,
    fuelRate: 2.5
};

// Global element references - just like qb-fuel
const $liter = $("#liter");
const $price = $("#price");
const $form = $("#fuel-form");
const $inputProgressFill = $("#input-progress-fill");

// Elements
const $fuelInputCard = $("#fuel-input-card");
const $pumpDisplayCard = $("#pump-display-card");
const $stationName = $("#station-name");

// Pump display elements
const $litresPumped = $("#litres-pumped");
const $totalCost = $("#total-cost");
const $pricePerLitre = $("#price-per-litre");
const $pumpProgressFill = $("#pump-progress-fill");
const $progressPercentage = $("#progress-percentage");
const $currentRate = $("#current-rate");
const $stationNameInput = $("#station-name-input");


// Show/Hide
const showFuelInputCard = () => {
    if ($managementTablet) $managementTablet.classList.remove("show");
    
    document.body.style.display = "block";
    document.body.style.pointerEvents = "auto";
    $fuelInputCard.classList.add("show");
    $pumpDisplayCard.classList.remove("show");
    
    setTimeout(() => {
        if ($liter) $liter.focus();
    }, 100);
};

const showPumpDisplayCard = () => {
    if ($managementTablet) $managementTablet.classList.remove("show");
    
    document.body.style.display = "block";
    document.body.style.pointerEvents = "auto";
    $fuelInputCard.classList.remove("show");
    $pumpDisplayCard.classList.add("show");
};

const hideAllCards = () => {
    $fuelInputCard.classList.remove("show");
    $pumpDisplayCard.classList.remove("show");
    if ($managementTablet) $managementTablet.classList.remove("show");
    setTimeout(() => {
        document.body.style.display = "none";
        document.body.style.pointerEvents = "none";
    }, 250);
};


const formatNumber = (num, decimals = 2) => Number(num).toFixed(decimals);
let CURRENCY_SYMBOL = "$";
const formatCurrency = (num) => `${CURRENCY_SYMBOL}${formatNumber(num, 2)}`;

let fuelingInterval = null;

const startFueling = () => {
    if (fuelingData.isActive) return;
    fuelingData.isActive = true;
    fuelingData.startTime = Date.now();
    updatePumpDisplay();

    fuelingInterval = setInterval(() => {
        if (!fuelingData.isActive) {
            clearInterval(fuelingInterval);
            return;
        }

        const timeElapsed = (Date.now() - fuelingData.startTime) / 1000;
        const fuelPumped = Math.min(timeElapsed * fuelingData.fuelRate, fuelingData.targetLitres);
        fuelingData.currentLitres = fuelPumped;
        fuelingData.totalCost = fuelPumped * fuelingData.pricePerLitre;
        updatePumpDisplay();

        if (fuelPumped >= fuelingData.targetLitres) {
            stopFueling(true);
        }
    }, 100);
};

const stopFueling = (completed = false) => {
    if (!fuelingData.isActive) return;
    fuelingData.isActive = false;
    if (fuelingInterval) {
        clearInterval(fuelingInterval);
        fuelingInterval = null;
    }

    const actualLitres = Math.max(0, Math.floor(fuelingData.currentLitres * 10) / 10);
    const completedFlag = Boolean(completed);
    $post("/pump-complete", { litres: actualLitres, completed: completedFlag });

    setTimeout(() => {
        hideAllCards();
        resetFuelingData();
    }, completed ? 1600 : 400);
};

const updatePumpDisplay = () => {
    const progress = fuelingData.targetLitres > 0 ? (fuelingData.currentLitres / fuelingData.targetLitres) * 100 : 0;
    if ($litresPumped) $litresPumped.textContent = formatNumber(fuelingData.currentLitres);
    if ($pricePerLitre) $pricePerLitre.textContent = formatCurrency(fuelingData.pricePerLitre);
    const total = fuelingData.currentLitres * fuelingData.pricePerLitre;
    fuelingData.totalCost = total;
    if ($totalCost) $totalCost.textContent = formatCurrency(total);
    if ($pumpProgressFill) $pumpProgressFill.style.width = `${progress}%`;
    if ($progressPercentage) $progressPercentage.textContent = `${Math.round(progress)}%`;
    if ($currentRate) $currentRate.textContent = `${fuelingData.fuelRate} L/s`;
};

const resetFuelingData = () => {
    fuelingData = {
        targetLitres: 0,
        currentLitres: 0,
        pricePerLitre: 0,
        totalCost: 0,
        isActive: false,
        startTime: 0,
        fuelRate: 2.5
    };
};

// Translations
const setupTranslations = (language) => {
    document.documentElement.lang = language;
    const translations = TRANSLATIONS[language] ?? TRANSLATIONS["en"];
    const elements = document.querySelectorAll("[data-translations]");
    elements.forEach((element) => {
        const key = element.dataset.translations;
        if (!translations[key]) return;
        if (element.children.length > 0) {
            let translation = translations[key];
            [...element.children].forEach((child) => {
                translation = translation.replace(`%{${child.id}}`, child.outerHTML);
            });
            element.innerHTML = translation;
            return;
        }
        element.innerText = translations[key];
    });
};

const updateLimits = () => {
    const $capacity = $("#capacity");
    const maxLiter = MAX_LITER - CURRENT_FUEL;
    if ($capacity) $capacity.innerText = CURRENT_FUEL;
    if ($liter) {
        $liter.max = maxLiter;
        $liter.min = 0;
        $liter.step = 1;
    }
    if ($price) {
        $price.max = Math.floor(maxLiter * LITER_PRICE);
        $price.step = LITER_PRICE;
    }
};

if ($liter) {
    $liter.addEventListener("input", () => {
        if ($liter.value === "") return ($liter.value = 0);
        let liter = parseFloat($liter.value);
        const maxLiter = MAX_LITER - CURRENT_FUEL;
        if (liter > maxLiter) {
            $liter.value = maxLiter;
            liter = maxLiter;
        }
        const price = Math.floor(liter * LITER_PRICE);
        if ($price) $price.value = price;
        if ($inputProgressFill) {
            const pct = ((CURRENT_FUEL + liter) / MAX_LITER) * 100;
            $inputProgressFill.style.width = `${pct}%`;
        }
    });
}

if ($price) {
    $price.addEventListener("input", () => {
        if ($price.value === "") return ($price.value = 0);
        const price = parseFloat($price.value);
        const liter = Math.floor(price / LITER_PRICE);
        if ($liter) $liter.value = liter;
        if ($inputProgressFill) {
            const pct = ((CURRENT_FUEL + liter) / MAX_LITER) * 100;
            $inputProgressFill.style.width = `${pct}%`;
        }
    });
}

if ($form) {
    $form.addEventListener("submit", (e) => {
        e.preventDefault();

        const liter = parseFloat($liter?.value || 0);
        const price = parseFloat($price?.value || 0);

        if (liter === 0 || price === 0) {
            return;
        }

        if ($liter) $liter.value = 0;
        if ($price) $price.value = 0;
        if ($inputProgressFill) $inputProgressFill.style.width = "0%";

        $post("/start-fueling", { liter });
    });
}


// Global handlers
const setupGlobalHandlers = () => {
    document.addEventListener("keydown", (e) => {
        if (e.key === "Escape") {
            if (progressData.isActive) {
                cancelProgressBar();
            } else if ($managementTablet && $managementTablet.classList.contains("show")) {
                hideManagement();
                $post("/close-management");
            } else if (!fuelingData.isActive) {
                $post("/close");
            }
        }
    });
};

// Message routing
window.addEventListener("message", ({ data }) => {
    switch (data.action) {
        case "show-input":
            LITER_PRICE = data.price || 5;
            CURRENT_FUEL = data.currentFuel || 0;
            if (data.currency) CURRENCY_SYMBOL = data.currency;
            if ($stationName) $stationName.textContent = data.stationName || "Gas Station";
            if ($stationNameInput) $stationNameInput.textContent = data.stationName || "Gas Station";
            updateLimits();
            showFuelInputCard();
            break;
        case "start-pump":
            if (typeof data.targetLitres === "number" && data.targetLitres > 0) {
                fuelingData.targetLitres = data.targetLitres;
            }
            if (typeof data.pricePerLitre === "number" && data.pricePerLitre > 0) {
                fuelingData.pricePerLitre = data.pricePerLitre;
            } else {
                fuelingData.pricePerLitre = LITER_PRICE;
            }
            if ($stationName) $stationName.textContent = data.stationName || $stationName.textContent;
            fuelingData.currentLitres = 0;
            fuelingData.totalCost = 0;
            showPumpDisplayCard();
            startFueling();
            break;
        case "stop-pump":
            stopFueling(false);
            break;
        case "hide":
            if (!fuelingData.isActive) hideAllCards();
            break;
        case "show-input-again":
            LITER_PRICE = data.price || LITER_PRICE;
            CURRENT_FUEL = data.currentFuel || CURRENT_FUEL;
            if (data.currency) CURRENCY_SYMBOL = data.currency;
            if (data.stationName && $stationName) $stationName.textContent = data.stationName;
            showFuelInputCard();
            break;
        case "setLanguage":
            setupTranslations(data.language);
            break;
        case "show-management":
            if (data.currency) CURRENCY_SYMBOL = data.currency;
            updateMainDashboard(data);
            showManagement();
            break;
        case "hide-management":
            hideManagement();
            break;
        case "update-management":
            updateMainDashboard(data);
            break;
        case "show-transactions":
            updateTransactions(data.transactions);
            break;
        case "show-statistics":
            updateStatistics(data.stats);
            break;
        case "show-progress":
            showProgressBar(data.label, data.duration, data.canCancel);
            break;
        case "hide-progress":
            finishProgressBar(false);
            break;
    }
});

// Init
setupTranslations("en");
setupGlobalHandlers();

let progressData = {
    isActive: false,
    duration: 0,
    startTime: 0,
    canCancel: false,
    onFinish: null,
    onCancel: null
};

const $progressContainer = $("#progress-container");
const $progressLabel = $("#progress-label");
const $progressBarFill = $("#progress-bar-fill");
const $progressPercent = $("#progress-percent");
const $progressCancelContainer = $("#progress-cancel-container");

let progressInterval = null;

const showProgressBar = (label, duration, canCancel) => {
    if (progressData.isActive) return;
    
    console.log('[SG-FUEL] Starting progress bar:', label, 'Duration:', duration + 'ms', 'Cancelable:', canCancel);
    
    progressData.isActive = true;
    progressData.duration = duration;
    progressData.startTime = Date.now();
    progressData.canCancel = canCancel;
    
    document.body.style.display = "block";
    
    if ($progressLabel) $progressLabel.textContent = label || "Processing...";
    if ($progressBarFill) $progressBarFill.style.width = "0%";
    if ($progressPercent) $progressPercent.textContent = "0%";
    if ($progressCancelContainer) {
        $progressCancelContainer.style.display = canCancel ? "block" : "none";
    }
    
    if ($progressContainer) {
        $progressContainer.classList.add("show");
        $progressContainer.style.display = "block";
    }
    
    progressInterval = setInterval(() => {
        if (!progressData.isActive) {
            clearInterval(progressInterval);
            return;
        }
        
        const elapsed = Date.now() - progressData.startTime;
        const progress = Math.min((elapsed / progressData.duration) * 100, 100);
        
        if ($progressBarFill) $progressBarFill.style.width = `${progress}%`;
        if ($progressPercent) $progressPercent.textContent = `${Math.round(progress)}%`;
        
        if (progress >= 100) {
            finishProgressBar(true);
        }
    }, 50);
};

const finishProgressBar = (completed) => {
    if (!progressData.isActive) return;
    
    progressData.isActive = false;
    
    if (progressInterval) {
        clearInterval(progressInterval);
        progressInterval = null;
    }
    
    if ($progressContainer) {
        $progressContainer.classList.remove("show");
        $progressContainer.style.display = "";
    }
    
    const fuelInputVisible = $fuelInputCard && $fuelInputCard.classList.contains("show");
    const pumpDisplayVisible = $pumpDisplayCard && $pumpDisplayCard.classList.contains("show");
    const managementVisible = $managementTablet && $managementTablet.classList.contains("show");
    
    if (!fuelInputVisible && !pumpDisplayVisible && !managementVisible) {
        setTimeout(() => {
            document.body.style.display = "none";
            document.body.style.pointerEvents = "none";
        }, 300);
    }
    
    $post("/progress-complete", { completed: completed });
    
    progressData = {
        isActive: false,
        duration: 0,
        startTime: 0,
        canCancel: false
    };
};

const cancelProgressBar = () => {
    if (progressData.isActive && progressData.canCancel) {
        finishProgressBar(false);
    }
};

let managementData = {
    business: null,
    businessName: "",
    fuelLitres: 0,
    balance: 0,
    todayIncome: 0,
    weeklyIncome: 0,
    fuelPrice: 0,
    isBoss: false,
    deliveryStatus: null
};

const $managementTablet = $("#management-tablet");
const $managementMain = $("#management-main");
const $managementSettings = $("#management-settings");
const $managementPrice = $("#management-price");
const $managementOrder = $("#management-order");
const $managementTransactions = $("#management-transactions");
const $managementStatistics = $("#management-statistics");

const showManagement = () => {
    if ($managementTablet) {
        if ($fuelInputCard) $fuelInputCard.classList.remove("show");
        if ($pumpDisplayCard) $pumpDisplayCard.classList.remove("show");
        
        $managementTablet.classList.add("show");
        document.body.style.display = "block";
        document.body.style.pointerEvents = "auto";
    }
};

const hideManagement = () => {
    if ($managementTablet) {
        $managementTablet.classList.remove("show");
        setTimeout(() => {
            const fuelInputVisible = $fuelInputCard && $fuelInputCard.classList.contains("show");
            const pumpDisplayVisible = $pumpDisplayCard && $pumpDisplayCard.classList.contains("show");
            
            if (!fuelInputVisible && !pumpDisplayVisible) {
                document.body.style.display = "none";
                document.body.style.pointerEvents = "none";
            }
            showPage("main");
        }, 300);
    }
};

const showPage = (pageName) => {
    const pages = {
        main: $managementMain,
        settings: $managementSettings,
        price: $managementPrice,
        order: $managementOrder,
        transactions: $managementTransactions,
        statistics: $managementStatistics
    };

    Object.values(pages).forEach(page => {
        if (page) page.style.display = "none";
    });

    if (pages[pageName]) {
        pages[pageName].style.display = "flex";
    }
};

const formatNumberWithCommas = (num) => {
    return Math.floor(num).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
};

const formatCurrencyMgmt = (num) => {
    return `${CURRENCY_SYMBOL}${formatNumberWithCommas(num)}`;
};

const updateMainDashboard = (data) => {
    managementData = { ...data };
    
    const maxCapacity = 50000;
    const fuelPercentage = (data.fuelLitres / maxCapacity) * 100;
    
    let status = "Low";
    if (fuelPercentage >= 70) status = "Good";
    else if (fuelPercentage >= 30) status = "Moderate";
    
    if ($("#mgmt-station-name")) $("#mgmt-station-name").textContent = data.businessName || data.business;
    if ($("#mgmt-status")) $("#mgmt-status").textContent = `${status} (${fuelPercentage.toFixed(1)}%)`;
    if ($("#mgmt-fuel")) $("#mgmt-fuel").textContent = `${formatNumberWithCommas(data.fuelLitres)}/${formatNumberWithCommas(maxCapacity)} L`;
    if ($("#mgmt-balance")) $("#mgmt-balance").textContent = formatCurrencyMgmt(data.balance);
    if ($("#mgmt-today")) $("#mgmt-today").textContent = formatCurrencyMgmt(data.todayIncome || 0);
    if ($("#mgmt-weekly")) $("#mgmt-weekly").textContent = formatCurrencyMgmt(data.weeklyIncome || 0);
    
    const deliveryCard = $("#delivery-status-card");
    const deliveryText = $("#mgmt-delivery");
    if (data.deliveryStatus && deliveryCard && deliveryText) {
        deliveryCard.style.display = "flex";
        let statusText = "No delivery";
        if (data.deliveryStatus.status === "pending") statusText = "⏳ Pending";
        else if (data.deliveryStatus.status === "in_progress") statusText = "🚛 In Progress";
        else if (data.deliveryStatus.status === "completed") statusText = "✅ Completed";
        deliveryText.textContent = statusText;
    } else if (deliveryCard) {
        deliveryCard.style.display = "none";
    }
    
    const orderBtn = $("#btn-order-fuel");
    if (orderBtn) {
        orderBtn.style.display = data.isBoss ? "block" : "none";
    }
    
    const priceDisplay = $("#current-price-display");
    if (priceDisplay) {
        priceDisplay.textContent = `Current: ${formatCurrencyMgmt(data.fuelPrice)} per litre`;
    }
    
    const setPriceBtn = $("#btn-set-price");
    if (setPriceBtn) {
        setPriceBtn.style.display = data.isBoss ? "flex" : "none";
    }
};

const updateTransactions = (transactions) => {
    const list = $("#transactions-list");
    if (!list) return;
    
    list.innerHTML = "";
    
    if (!transactions || transactions.length === 0) {
        list.innerHTML = '<div class="transaction-item"><div class="transaction-desc">No recent transactions</div></div>';
        return;
    }
    
    transactions.forEach(transaction => {
        const item = document.createElement("div");
        item.className = "transaction-item";
        
        const isPositive = transaction.statement_type === "deposit";
        const amountClass = isPositive ? "positive" : "negative";
        const prefix = isPositive ? "+ " : "- ";
        
        item.innerHTML = `
            <div class="transaction-header">
                <span class="transaction-amount ${amountClass}">${prefix}${formatCurrencyMgmt(Math.abs(transaction.amount))}</span>
            </div>
            <div class="transaction-desc">${transaction.description || "N/A"}</div>
            <div class="transaction-date">${transaction.created || "N/A"}</div>
        `;
        
        list.appendChild(item);
    });
};

const updateStatistics = (stats) => {
    const grid = $("#stats-grid");
    if (!grid) return;
    
    grid.innerHTML = "";
    
    const analytics = stats.fuel_analytics || {};
    const totalSales = parseFloat(analytics.total_sales) || 0;
    const litresSold = parseFloat(analytics.litres_sold) || 0;
    const profit = parseFloat(analytics.profit) || 0;
    const deliveryCost = Math.abs(parseFloat(analytics.delivery_cost) || 0);
    
    const cards = [
        {
            title: "📊 Weekly Performance",
            content: `Total Income: ${formatCurrencyMgmt(stats.weekly_income || 0)}`
        },
        {
            title: "⛽ Fuel Sales (7 Days)",
            content: `
Transactions: ${analytics.customer_transactions || 0}
Litres Sold: ${formatNumberWithCommas(litresSold)}
Avg per Sale: ${(analytics.avg_litres_per_sale || 0).toFixed(1)} litres
Revenue per Litre: ${formatCurrencyMgmt(litresSold > 0 ? (totalSales / litresSold) : 0)}`
        },
        {
            title: "💰 Financial Overview",
            content: `
Sales Revenue: ${formatCurrencyMgmt(totalSales)}
Supply Cost: ${formatCurrencyMgmt(deliveryCost)}
Profit: ${formatCurrencyMgmt(profit)}
Profit Margin: ${totalSales > 0 ? ((profit / totalSales) * 100).toFixed(1) : 0}%`
        },
        {
            title: "📦 Supply Details",
            content: `
Deliveries: ${analytics.delivery_count || 0} (${formatNumberWithCommas(analytics.delivery_litres || 0)} litres)
Current Stock: ${formatNumberWithCommas(stats.fuel_level || 0)} litres
Avg Transaction: ${formatCurrencyMgmt(analytics.avg_transaction || 0)}`
        }
    ];
    
    cards.forEach(card => {
        const cardEl = document.createElement("div");
        cardEl.className = "stat-card";
        cardEl.innerHTML = `
            <div class="stat-title">${card.title}</div>
            <div class="stat-content">${card.content}</div>
        `;
        grid.appendChild(cardEl);
    });
};

if ($("#close-management")) {
    $("#close-management").addEventListener("click", () => {
        hideManagement();
        $post("/close-management");
    });
}

if ($("#btn-settings")) {
    $("#btn-settings").addEventListener("click", () => showPage("settings"));
}

if ($("#btn-order-fuel")) {
    $("#btn-order-fuel").addEventListener("click", () => {
        showPage("order");
        const orderAmount = $("#order-amount");
        if (orderAmount) orderAmount.value = "";
    });
}

if ($("#back-from-settings")) {
    $("#back-from-settings").addEventListener("click", () => showPage("main"));
}

if ($("#btn-set-price")) {
    $("#btn-set-price").addEventListener("click", () => {
        showPage("price");
        const priceInput = $("#price-input");
        const priceHint = $("#price-hint");
        if (priceInput) priceInput.value = managementData.fuelPrice;
        if (priceHint) priceHint.textContent = `Current price: ${formatCurrencyMgmt(managementData.fuelPrice)}`;
    });
}

if ($("#back-from-price")) {
    $("#back-from-price").addEventListener("click", () => showPage("settings"));
}

if ($("#submit-price")) {
    $("#submit-price").addEventListener("click", () => {
        const priceInput = $("#price-input");
        if (priceInput && priceInput.value) {
            const newPrice = parseFloat(priceInput.value);
            if (newPrice > 0) {
                $post("/set-fuel-price", { price: newPrice, business: managementData.business });
                showPage("main");
            }
        }
    });
}

if ($("#back-from-order")) {
    $("#back-from-order").addEventListener("click", () => showPage("main"));
}

if ($("#order-amount")) {
    $("#order-amount").addEventListener("input", (e) => {
        const amount = parseFloat(e.target.value) || 0;
        const orderHint = $("#order-hint");
        if (orderHint) {
            const cost = amount * 10000;
            orderHint.textContent = `Cost: ${formatCurrencyMgmt(cost)}`;
        }
    });
}

if ($("#submit-order")) {
    $("#submit-order").addEventListener("click", () => {
        const orderAmount = $("#order-amount");
        if (orderAmount && orderAmount.value) {
            const amount = parseFloat(orderAmount.value);
            if (amount > 0) {
                $post("/order-fuel", { amount: amount, business: managementData.business });
                showPage("main");
            }
        }
    });
}

if ($("#btn-transactions")) {
    $("#btn-transactions").addEventListener("click", () => {
        showPage("transactions");
        $post("/request-transactions", { business: managementData.business });
    });
}

if ($("#back-from-transactions")) {
    $("#back-from-transactions").addEventListener("click", () => showPage("settings"));
}

if ($("#btn-statistics")) {
    $("#btn-statistics").addEventListener("click", () => {
        showPage("statistics");
        $post("/request-statistics", { business: managementData.business });
    });
}

if ($("#back-from-statistics")) {
    $("#back-from-statistics").addEventListener("click", () => showPage("settings"));
}