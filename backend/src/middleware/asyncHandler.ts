import type { NextFunction, Request, Response } from 'express';

type AsyncHandler = (
  req: Request,
  res: Response,
  next: NextFunction,
) => Promise<void>;

type ExpressHandler = (
  req: Request,
  res: Response,
  next: NextFunction,
) => void;

/**
 * Wraps an async route handler so that rejected promises are forwarded to
 * Express's error middleware (Express 4 does not do this automatically).
 */
export function asyncHandler(handler: AsyncHandler): ExpressHandler {
  return (req, res, next) => {
    handler(req, res, next).catch(next);
  };
}