/*
    SPDX-FileCopyrightText: 2013 Aurélien Gâteau <agateau@kde.org>
    SPDX-FileCopyrightText: 2013-2015 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2017 Ivan Cukic <ivan.cukic@kde.org>
    SPDX-FileCopyrightText: 2022 ivan tkachenko <me@ratijas.tk>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library
.import org.kde.plasma.core as PlasmaCore

const defaultIconName = "start-here-kde-symbolic";

function iconOrDefault(formFactor, preferredIconName) {
    // Vertical panels must have an icon, at least a default one.
    return (formFactor === PlasmaCore.Types.Vertical && preferredIconName === "")
        ? defaultIconName : preferredIconName;
}

function createFavoriteActions(i18n, favoriteModel, favoriteId) {
    if (!favoriteModel || !favoriteId || !favoriteModel.enabled) {
        return null;
    }


    if (favoriteModel.activities === undefined ||
        favoriteModel.activities.activities.length <= 1) {
        const action = {};

        if (favoriteModel.isFavorite(favoriteId)) {
            action.text = i18n("Remove from Favorites");
            action.icon = "bookmark-remove";
            action.actionId = "_kicker_favorite_remove";
        } else if (favoriteModel.maxFavorites === -1 || favoriteModel.count < favoriteModel.maxFavorites) {
            action.text = i18n("Add to Favorites");
            action.icon = "bookmark-new";
            action.actionId = "_kicker_favorite_add";
        } else {
            return null;
        }

        action.actionArgument = { favoriteModel: favoriteModel, favoriteId: favoriteId };

        return [action];

    } else {
        const subActions = [];

        const linkedActivities = favoriteModel.linkedActivitiesFor(favoriteId);

        const activities = favoriteModel.activities.activities;

        // Adding the item to link/unlink to all activities

        const linkedToAllActivities =
            !(linkedActivities.indexOf(":global") === -1);

        subActions.push({
            text      : i18n("On All Activities"),
            checkable : true,

            actionId  : linkedToAllActivities ?
                            "_kicker_favorite_remove_from_activity" :
                            "_kicker_favorite_set_to_activity",
            checked   : linkedToAllActivities,

            actionArgument : {
                favoriteModel: favoriteModel,
                favoriteId: favoriteId,
                favoriteActivity: "",
            },
        });


        // Adding items for each activity separately

        const addActivityItem = function(activityId, activityName) {
            const linkedToThisActivity =
                !(linkedActivities.indexOf(activityId) === -1);

            subActions.push({
                text      : activityName,
                checkable : true,
                checked   : linkedToThisActivity && !linkedToAllActivities,

                actionId :
                    // If we are on all activities, and the user clicks just one
                    // specific activity, unlink from everything else
                    linkedToAllActivities ? "_kicker_favorite_set_to_activity" :

                    // If we are linked to the current activity, just unlink from
                    // that single one
                    linkedToThisActivity ? "_kicker_favorite_remove_from_activity" :

                    // Otherwise, link to this activity, but do not unlink from
                    // other ones
                    "_kicker_favorite_add_to_activity",

                actionArgument : {
                    favoriteModel    : favoriteModel,
                    favoriteId       : favoriteId,
                    favoriteActivity : activityId,
                },
            });
        };

        // Adding the item to link/unlink to the current activity

        addActivityItem(favoriteModel.activities.currentActivity, i18n("On the Current Activity"));

        subActions.push({
            type: "separator",
            actionId: "_kicker_favorite_separator",
        });

        // Adding the items for each activity

        activities.forEach(function(activityId) {
            addActivityItem(activityId, favoriteModel.activityNameForId(activityId));
        });

        return [{
            text       : i18n("Show in Favorites"),
            icon       : "favorite",
            subActions,
        }];
    }
}

function triggerAction(model, index, actionId, actionArgument) {
    function startsWith(txt, needle) {
        return txt.substr(0, needle.length) === needle;
    }

    if (startsWith(actionId, "_kicker_favorite_")) {
        handleFavoriteAction(actionId, actionArgument);
        return;
    }

    const closeRequested = model.trigger(index, actionId, actionArgument);

    if (closeRequested) {
        return true;
    }

    return false;
}

function handleFavoriteAction(actionId, actionArgument) {
    const favoriteId = actionArgument.favoriteId;
    const favoriteModel = actionArgument.favoriteModel;

    if (favoriteModel === null || favoriteId === null) {
        return null;
    }

    if (actionId === "_kicker_favorite_remove") {
        favoriteModel.removeFavorite(favoriteId);
    } else if (actionId === "_kicker_favorite_add") {
        favoriteModel.addFavorite(favoriteId);
    } else if (actionId === "_kicker_favorite_remove_from_activity") {
        favoriteModel.removeFavoriteFrom(favoriteId, actionArgument.favoriteActivity);
    } else if (actionId === "_kicker_favorite_add_to_activity") {
        favoriteModel.addFavoriteTo(favoriteId, actionArgument.favoriteActivity);
    } else if (actionId === "_kicker_favorite_set_to_activity") {
        favoriteModel.setFavoriteOn(favoriteId, actionArgument.favoriteActivity);
    }
}

/**
 * Compute smart suggestion scores based on frequent usage + time of day.
 *
 * @param {Object} frequentModel - Kicker.RecentUsageModel with ordering=1
 * @param {Object} favoritesModel - The favorites model (to filter duplicates)
 * @param {number} maxItems - Maximum number of suggestions to return
 * @returns {Array<{index: number, score: number}>} Sorted by score descending
 */
function computeSmartScores(frequentModel, favoritesModel, maxItems) {
    if (!frequentModel || frequentModel.count === 0) {
        return [];
    }

    // Time weight: different multipliers by time of day
    const hour = new Date().getHours();
    let timeWeight = 1.0;
    if (hour >= 6 && hour < 12) {
        timeWeight = 1.2; // Morning boost (work apps)
    } else if (hour >= 12 && hour < 18) {
        timeWeight = 1.0; // Afternoon neutral
    } else if (hour >= 18 && hour < 24) {
        timeWeight = 0.8; // Evening (entertainment boost relative to work)
    } else {
        timeWeight = 0.6; // Late night
    }

    const results = [];

    for (let i = 0; i < frequentModel.count && results.length < maxItems * 2; i++) {
        const idx = frequentModel.index(i, 0);
        const display = frequentModel.data(idx, Qt.DisplayRole);

        if (!display || display.length === 0) continue;

        // Skip items already in favorites (avoid duplicates)
        const favoriteId = frequentModel.data(idx, frequentModel.KItemModels
            ? frequentModel.KItemModels.KRoleNames.role("favoriteId")
            : 0);

        // Calculate position-based frequency score (higher position = higher frequency)
        const positionScore = (frequentModel.count - i) / frequentModel.count;
        const score = positionScore * timeWeight;

        results.push({ index: i, score: score });
    }

    // Sort by score descending
    results.sort(function(a, b) { return b.score - a.score; });

    // Return only maxItems
    return results.slice(0, maxItems);
}

