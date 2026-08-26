/**
 * Wraps an async route handler so that rejected promises are forwarded to
 * Express's error middleware (Express 4 does not do this automatically).
 */
export function asyncHandler(handler) {
    return (req, res, next) => {
        handler(req, res, next).catch(next);
    };
}
//# sourceMappingURL=asyncHandler.js.map